# Allocation bridges for the source perfect-tree model (bendlang/bend#2213).
import Base
import ./f32array.bend as A
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ../lemmas/perfect.bend as P
import ../lemmas/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N
import ./layout-proof.bend as Layout

# A replicated zero list may be shorter than the tree: P.nth defaults to zero.
def replicate(-T: Data, +zero: T, n: Nat) -> List<&2, T>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{zero, replicate(T, zero, p)}

def replicate_len(-T: Data, +zero: T, +n: Nat) -> {P.len(T, zero, replicate(T, zero, n)) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      Equal.cong(Nat, Nat, x => 1n+x, P.len(T, zero, replicate(T, zero, p)), p, replicate_len(T, zero, p))

def replicate_drop(-T: Data, +zero: T, +k: Nat, +n: Nat) -> {P.drop(T, zero, k, replicate(T, zero, n)) == replicate(T, zero, Nat.sub(n, k)) : List<&2, T>}:
  match k:
    case 0n:
      %P.sub_zero(n) : {P.drop(T, zero, 0n, replicate(T, zero, n)) == replicate(T, zero, _) : List<&2, T>}
      {==}
    case 1n++p:
      match n:
        case 0n:
          {==}
        case 1n++q:
          replicate_drop(T, zero, p, q)

def replicate_head(-T: Data, +zero: T, n: Nat) -> {P.nth(T, zero, replicate(T, zero, n), 0n) == zero : T}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

# Structural induction on the actual Array.new, not an allocator assumption.
def new_build(-T: Data, +zero: T, +d: Nat, +n: Nat) -> {Array.new(T, d, zero) == P.build(T, zero, d, replicate(T, zero, n)) : Array<T>}:
  match d:
    case 0n:
      Equal.sym(Array<T>, ALeaf{P.nth(T, zero, replicate(T, zero, n), 0n)}, ALeaf{zero},
        Equal.cong(T, Array<T>, x => ALeaf{x}, P.nth(T, zero, replicate(T, zero, n), 0n), zero, replicate_head(T, zero, n)))
    case 1n++e:
      %Equal.sym(List<&2, T>, P.drop(T, zero, Nat.pow(2n, e), replicate(T, zero, n)), replicate(T, zero, Nat.sub(n, Nat.pow(2n, e))), replicate_drop(T, zero, Nat.pow(2n, e), n)) : {Array.new(T, 1n+e, zero) == ANode{P.build(T, zero, e, replicate(T, zero, n)), P.build(T, zero, e, _)} : Array<T>}
      %new_build(T, zero, e, n) : {ANode{Array.new(T, e, zero), Array.new(T, e, zero)} == ANode{_, P.build(T, zero, e, replicate(T, zero, Nat.sub(n, Nat.pow(2n, e))))} : Array<T>}
      %new_build(T, zero, e, Nat.sub(n, Nat.pow(2n, e))) : {ANode{Array.new(T, e, zero), Array.new(T, e, zero)} == ANode{Array.new(T, e, zero), _} : Array<T>}
      {==}

def cell_depth(+len: U32) -> Nat:
  Bytes.depth(A.cells(len))

def word_depth(+len: U32) -> Nat:
  Bytes.depth(Bytes.words((len << 2n : U32)))

def cell_capacity(+len: U32) -> Nat:
  Nat.pow(2n, cell_depth(len))

def word_capacity(+len: U32) -> Nat:
  Nat.pow(2n, word_depth(len))

def alloc_cells(+len: U32) -> {A.alloc(len) == P.build(A.Cell, A.zero(), cell_depth(len), replicate(A.Cell, A.zero(), cell_capacity(len))) : Array<A.Cell>}:
  new_build(A.Cell, A.zero(), cell_depth(len), cell_capacity(len))

def alloc_words(+len: U32) -> {Bytes.alloc((len << 2n : U32)) == P.build(U32, 0, word_depth(len), replicate(U32, 0, word_capacity(len))) : Array<U32>}:
  new_build(U32, 0, word_depth(len), word_capacity(len))

# Bridge the two existing power-of-two definitions without evaluating 2^32.
def pow_bridge(+d: Nat) -> {L.pow2(d) == Nat.pow(2n, d) : Nat}:
  match d:
    case 0n:
      {==}
    case 1n++e:
      %P.tps(e) : {Nat.double(L.pow2(e)) == _ : Nat}
      %Equal.sym(Nat, L.pow2(e), Nat.pow(2n, e), pow_bridge(e)) : {Nat.double(_) == Nat.double(Nat.pow(2n, e)) : Nat}
      {==}

def pow_le(+a: Nat, +b: Nat, +h: P.le(a, b)) -> P.le(L.pow2(a), L.pow2(b)):
  match a:
    case 0n:
      %Equal.sym(Nat, L.pow2(b), Nat.pow(2n, b), pow_bridge(b)) : P.le(1n, _)
      P.one_le_pow(b)
    case 1n++p:
      match b:
        case 0n:
          P.efq(P.le(L.pow2(1n+p), L.pow2(0n)), P.ft(h))
        case 1n++q:
          N.double_le_double(L.pow2(p), L.pow2(q), pow_le(p, q, h))

def lt_double(+n: Nat, +h: P.le(1n, n)) -> P.lt(n, Nat.double(n)):
  match n:
    case 0n:
      P.efq(P.lt(0n, 0n), P.ft(h))
    case 1n++p:
      N.lt_of_le_of_lt(p, Nat.double(p), 1n+Nat.double(p),
        P.le_double(p), N.lt_succ_self(Nat.double(p)))

def pow_lt(+a: Nat, +b: Nat, +h: P.lt(a, b)) -> P.lt(L.pow2(a), L.pow2(b)):
  N.lt_of_lt_of_le(L.pow2(a), Nat.double(L.pow2(a)), L.pow2(b),
    lt_double(L.pow2(a),
      %Equal.sym(Nat, L.pow2(a), Nat.pow(2n, a), pow_bridge(a)) : P.le(1n, _)
      P.one_le_pow(a)),
    pow_le(1n+a, b, N.succ_le_of_lt(a, b, h)))

# Convert the literal separately from its bound: https://github.com/bendlang/bend/issues/1071.
def increment_exact(+i: U32, h: N.lt(Nat.add(U32.to_nat(i), 1n), L.pow2(32n))) ->
  {U32.to_nat((i + 1 : U32)) == Nat.add(U32.to_nat(i), 1n) : Nat}:
  L.u32_add_nat(i, 1, L.lt_rw(Nat.add(U32.to_nat(i), U32.to_nat(1)), Nat.add(U32.to_nat(i), 1n), L.pow2(32n),
    Equal.cong(Nat, Nat, k => Nat.add(U32.to_nat(i), k), U32.to_nat(1), 1n, {==}), h))

def increment_nat(+i: U32, +hi: P.lt(U32.to_nat(i), L.pow2(30n))) ->
  {U32.to_nat((i + 1 : U32)) == 1n+U32.to_nat(i) : Nat}:
  Equal.trans(Nat, U32.to_nat((i + 1 : U32)), Nat.add(U32.to_nat(i), 1n), 1n+U32.to_nat(i),
    increment_exact(i,
      N.lt_of_le_of_lt(Nat.add(U32.to_nat(i), 1n), Nat.add(U32.to_nat(i), 7n), L.pow2(32n),
        N.add_le_add_left(1n, 7n, U32.to_nat(i), {==}),
        Layout.nat_lt(Nat.add(U32.to_nat(i), 7n), L.pow2(32n), Layout.add7_bound(U32.to_nat(i), hi)))),
    N.add_comm(U32.to_nat(i), 1n))

def decrement_nat(+i: U32, +hi: P.le(1n, U32.to_nat(i))) ->
  {U32.to_nat((i - 1 : U32)) == Nat.sub(U32.to_nat(i), 1n) : Nat}:
  L.u32_sub_nat(i, 1, hi)

# A natural-number copy of the allocator's bounded doubling search.
def search(f: Nat, more: Bool, +w: Nat, +d: Nat) -> Nat:
  match f:
    case 0n:
      d
    case 1n+p:
      match more:
        case False{}:
          d
        case True{}:
          search(p, Nat.is_lt(L.pow2(1n+d), w), w, 1n+d)

def depth_stop(f: Nat, +w: U32, +d: Nat, +cap: U32) ->
  {Bytes.depth.go(f, False{}, w, d, cap) == d : Nat}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      {==}

def mul2(+n: Nat) -> {Nat.mul(n, 2n) == Nat.double(n) : Nat}:
  Equal.trans(Nat, Nat.mul(n, 2n), Nat.add(n, n), Nat.double(n), N.mul_two(n),
    Equal.sym(Nat, Nat.double(n), Nat.add(n, n), P.double_eq_add(n)))

# Transport multiplication's literal before its bound: https://github.com/bendlang/bend/issues/1071.
def double_exact(+cap: U32, h: N.lt(Nat.double(U32.to_nat(cap)), L.pow2(32n))) ->
  {U32.to_nat((cap * 2 : U32)) == Nat.double(U32.to_nat(cap)) : Nat}:
  +e = Equal.trans(Nat, Nat.mul(U32.to_nat(cap), U32.to_nat(2)), Nat.mul(U32.to_nat(cap), 2n), Nat.double(U32.to_nat(cap)),
    Equal.cong(Nat, Nat, k => Nat.mul(U32.to_nat(cap), k), U32.to_nat(2), 2n, {==}), mul2(U32.to_nat(cap)))
  Equal.trans(Nat, U32.to_nat((cap * 2 : U32)), Nat.mul(U32.to_nat(cap), U32.to_nat(2)), Nat.double(U32.to_nat(cap)),
    L.u32_mul_nat(cap, 2, L.lt_rw(Nat.mul(U32.to_nat(cap), U32.to_nat(2)), Nat.double(U32.to_nat(cap)), L.pow2(32n), e, h)), e)

def cap_double(+cap: U32, +d: Nat, +hd: P.lt(1n+d, 32n),
  +he: {U32.to_nat(cap) == L.pow2(d) : Nat}) ->
  {U32.to_nat((cap * 2 : U32)) == L.pow2(1n+d) : Nat}:
  +e = Equal.cong(Nat, Nat, Nat.double, U32.to_nat(cap), L.pow2(d), he)
  Equal.trans(Nat, U32.to_nat((cap * 2 : U32)), Nat.double(U32.to_nat(cap)), L.pow2(1n+d),
    double_exact(cap, L.lt_rw(Nat.double(U32.to_nat(cap)), L.pow2(1n+d), L.pow2(32n), e,
      Layout.nat_lt(L.pow2(1n+d), L.pow2(32n), pow_lt(1n+d, 32n, hd)))), e)

# Extra fuel is immaterial once the mathematical upper capacity covers w.
def depth_search(+f: Nat, +more: Bool, +extra: Nat, +w: U32, +d: Nat, +cap: U32,
  +he: {U32.to_nat(cap) == L.pow2(d) : Nat},
  +hb: {more == Nat.is_lt(L.pow2(d), U32.to_nat(w)) : Bool},
  +hd: P.lt(Nat.add(d, f), 32n),
  +hw: P.le(U32.to_nat(w), L.pow2(Nat.add(d, f)))) ->
  {Bytes.depth.go(Nat.add(f, extra), more, w, d, cap) == search(f, more, U32.to_nat(w), d) : Nat}:
  match f:
    case 0n:
      %Equal.sym(Bool, more, Nat.is_lt(L.pow2(d), U32.to_nat(w)), hb) :
        {Bytes.depth.go(extra, _, w, d, cap) == d : Nat}
      %Equal.sym(Bool, Nat.is_lt(L.pow2(d), U32.to_nat(w)), False{},
        N.not_lt_of_le(U32.to_nat(w), L.pow2(d),
          %Equal.sym(Nat, d, Nat.add(d, 0n), P.add_zero(d)) :
            P.le(U32.to_nat(w), L.pow2(_))
          hw)) : {Bytes.depth.go(extra, _, w, d, cap) == d : Nat}
      depth_stop(extra, w, d, cap)
    case 1n++p:
      match more:
        case False{}:
          {==}
        case True{}:
          +step = cap_double(cap, d,
            N.lt_of_le_of_lt(1n+d, Nat.add(d, 1n+p), 32n,
              %P.add_succ(d, p) : P.le(1n+d, _)
              N.succ_le_succ(d, Nat.add(d, p), N.le_add_right(d, p)), hd), he)
          +cmp = Equal.trans(Bool, U32.is_lt((cap * 2 : U32), w),
            Nat.is_lt(U32.to_nat((cap * 2 : U32)), U32.to_nat(w)),
            Nat.is_lt(L.pow2(1n+d), U32.to_nat(w)),
            L.u32_is_lt_nat((cap * 2 : U32), w),
            Equal.cong(Nat, Bool, x => Nat.is_lt(x, U32.to_nat(w)),
              U32.to_nat((cap * 2 : U32)), L.pow2(1n+d), step))
          %cmp :
            {Bytes.depth.go(Nat.add(p, extra), U32.is_lt((cap * 2 : U32), w), w, 1n+d, (cap * 2 : U32)) == search(p, _, U32.to_nat(w), 1n+d) : Nat}
          depth_search(p, U32.is_lt((cap * 2 : U32), w), extra, w, 1n+d, (cap * 2 : U32),
            step, cmp,
            %Equal.sym(Nat, 1n+Nat.add(d, p), Nat.add(d, 1n+p), P.add_succ(d, p)) :
              P.lt(_, 32n)
            hd,
            %Equal.sym(Nat, 1n+Nat.add(d, p), Nat.add(d, 1n+p), P.add_succ(d, p)) :
              P.le(U32.to_nat(w), L.pow2(_))
            hw)

def search_upper(+f: Nat, more: Bool, +w: Nat, +d: Nat) ->
  P.le(search(f, more, w, d), Nat.add(d, f)):
  match f:
    case 0n:
      %P.add_zero(d) : P.le(d, _)
      N.le_refl(d)
    case 1n++p:
      match more:
        case False{}:
          N.le_add_right(d, 1n+p)
        case True{}:
          %P.add_succ(d, p) : P.le(search(p, Nat.is_lt(L.pow2(1n+d), w), w, 1n+d), _)
          search_upper(p, Nat.is_lt(L.pow2(1n+d), w), w, 1n+d)

def search_covers(+f: Nat, +more: Bool, +w: Nat, +d: Nat,
  +hb: {more == Nat.is_lt(L.pow2(d), w) : Bool},
  +hw: P.le(w, L.pow2(Nat.add(d, f)))) ->
  P.le(w, L.pow2(search(f, more, w, d))):
  match f:
    case 0n:
      %Equal.sym(Nat, d, Nat.add(d, 0n), P.add_zero(d)) : P.le(w, L.pow2(_))
      hw
    case 1n++p:
      match more:
        case False{}:
          N.le_of_not_lt(L.pow2(d), w, Equal.sym(Bool, False{}, Nat.is_lt(L.pow2(d), w), hb))
        case True{}:
          search_covers(p, Nat.is_lt(L.pow2(1n+d), w), w, 1n+d, {==},
            %Equal.sym(Nat, 1n+Nat.add(d, p), Nat.add(d, 1n+p), P.add_succ(d, p)) :
              P.le(w, L.pow2(_))
            hw)

# Keep initial fuel symbolic during conversion: https://github.com/bendlang/bend/issues/1071.
def depth_initial(+f: Nat, +extra: Nat, +w: U32,
  +hf: P.lt(f, 32n), +hw: P.le(U32.to_nat(w), L.pow2(f))) ->
  {Bytes.depth.go(Nat.add(f, extra), U32.is_lt(1, w), w, 0n, 1) == search(f, Nat.is_lt(1n, U32.to_nat(w)), U32.to_nat(w), 0n) : Nat}:
  Equal.trans(Nat, Bytes.depth.go(Nat.add(f, extra), U32.is_lt(1, w), w, 0n, 1),
    search(f, U32.is_lt(1, w), U32.to_nat(w), 0n),
    search(f, Nat.is_lt(1n, U32.to_nat(w)), U32.to_nat(w), 0n),
    depth_search(f, U32.is_lt(1, w), extra, w, 0n, 1, {==}, L.u32_is_lt_nat(1, w), hf, hw),
    Equal.cong(Bool, Nat, b => search(f, b, U32.to_nat(w), 0n),
      U32.is_lt(1, w), Nat.is_lt(1n, U32.to_nat(w)), L.u32_is_lt_nat(1, w)))

def depth_model(+w: U32, +hw: P.le(U32.to_nat(w), L.pow2(30n))) ->
  {Bytes.depth(w) == search(30n, Nat.is_lt(1n, U32.to_nat(w)), U32.to_nat(w), 0n) : Nat}:
  depth_initial(30n, 2n, w, {==}, hw)

def depth_bound(+w: U32, +hw: P.le(U32.to_nat(w), L.pow2(30n))) ->
  P.lt(Bytes.depth(w), 32n):
  %Equal.sym(Nat, Bytes.depth(w), search(30n, Nat.is_lt(1n, U32.to_nat(w)), U32.to_nat(w), 0n), depth_model(w, hw)) : P.lt(_, 32n)
  N.lt_of_le_of_lt(search(30n, Nat.is_lt(1n, U32.to_nat(w)), U32.to_nat(w), 0n), 30n, 32n,
    search_upper(30n, Nat.is_lt(1n, U32.to_nat(w)), U32.to_nat(w), 0n), {==})

# Keep capacity transport symbolic: https://github.com/bendlang/bend/issues/1071.
def covers_depth(+w: Nat, +d: Nat, +e: Nat, he: {d == e : Nat},
  hw: P.le(w, L.pow2(e))) -> P.le(w, Nat.pow(2n, d)):
  %pow_bridge(d) : P.le(w, _)
  %Equal.sym(Nat, d, e, he) : P.le(w, L.pow2(_))
  hw

def search_initial_covers(+f: Nat, +w: Nat, hw: P.le(w, L.pow2(f))) ->
  P.le(w, L.pow2(search(f, Nat.is_lt(1n, w), w, 0n))):
  search_covers(f, Nat.is_lt(1n, w), w, 0n, {==}, hw)

def depth_covers(+w: U32, +hw: P.le(U32.to_nat(w), L.pow2(30n))) ->
  P.le(U32.to_nat(w), Nat.pow(2n, Bytes.depth(w))):
  covers_depth(U32.to_nat(w), Bytes.depth(w),
    search(30n, Nat.is_lt(1n, U32.to_nat(w)), U32.to_nat(w), 0n), depth_model(w, hw),
    search_initial_covers(30n, U32.to_nat(w), hw))

# The arithmetic reason rounding up to cells commutes with doubling capacity.
def ceil_cmp(+c: Nat, +n: Nat) ->
  {Nat.is_lt(c, Nat.div(Nat.add(n, 7n), 8n)) == Nat.is_lt(Nat.mul(c, 8n), n) : Bool}:
  %Equal.sym(Bool, Nat.is_lt(c, Nat.div(Nat.add(n, 7n), 8n)),
    Nat.is_le(1n+c, Nat.div(Nat.add(n, 7n), 8n)),
    N.is_lt_eq_succ_le(c, Nat.div(Nat.add(n, 7n), 8n))) : {_ == Nat.is_lt(Nat.mul(c, 8n), n) : Bool}
  %Equal.sym(Bool, Nat.is_le(1n+c, Nat.div(Nat.add(n, 7n), 8n)),
    Nat.is_le(Nat.mul(1n+c, 8n), Nat.add(n, 7n)),
    N.le_div_iff_mul_le(1n+c, Nat.add(n, 7n), 7n)) : {_ == Nat.is_lt(Nat.mul(c, 8n), n) : Bool}
  %Equal.sym(Nat, Nat.add(n, 7n), Nat.add(7n, n), N.add_comm(n, 7n)) :
    {Nat.is_le(Nat.mul(1n+c, 8n), _) == Nat.is_lt(Nat.mul(c, 8n), n) : Bool}
  %N.add_le_add_iff_left(7n, 1n+Nat.mul(c, 8n), n) :
    {_ == Nat.is_lt(Nat.mul(c, 8n), n) : Bool}
  Equal.sym(Bool, Nat.is_lt(Nat.mul(c, 8n), n), Nat.is_le(1n+Nat.mul(c, 8n), n),
    N.is_lt_eq_succ_le(Nat.mul(c, 8n), n))

def pow8(+d: Nat) -> {Nat.mul(L.pow2(d), 8n) == L.pow2(3n+d) : Nat}:
  %Equal.sym(Nat, Nat.mul(L.pow2(d), 8n), Nat.double(Nat.mul(L.pow2(d), 4n)), N.mul_double(L.pow2(d), 4n)) : {_ == L.pow2(3n+d) : Nat}
  %Equal.sym(Nat, Nat.mul(L.pow2(d), 4n), Nat.double(Nat.mul(L.pow2(d), 2n)), N.mul_double(L.pow2(d), 2n)) : {Nat.double(_) == L.pow2(3n+d) : Nat}
  %Equal.sym(Nat, Nat.mul(L.pow2(d), 2n), Nat.double(L.pow2(d)), mul2(L.pow2(d))) : {Nat.double(Nat.double(_)) == L.pow2(3n+d) : Nat}
  {==}

def ceil_pow_cmp(+d: Nat, +n: Nat) ->
  {Nat.is_lt(L.pow2(d), Nat.div(Nat.add(n, 7n), 8n)) == Nat.is_lt(L.pow2(3n+d), n) : Bool}:
  Equal.trans(Bool,
    Nat.is_lt(L.pow2(d), Nat.div(Nat.add(n, 7n), 8n)),
    Nat.is_lt(Nat.mul(L.pow2(d), 8n), n), Nat.is_lt(L.pow2(3n+d), n),
    ceil_cmp(L.pow2(d), n),
    Equal.cong(Nat, Bool, x => Nat.is_lt(x, n), Nat.mul(L.pow2(d), 8n), L.pow2(3n+d), pow8(d)))

def ceil_pow_bound(+d: Nat, +n: Nat, +h: P.le(n, L.pow2(3n+d))) ->
  P.le(Nat.div(Nat.add(n, 7n), 8n), L.pow2(d)):
  N.le_of_not_lt(L.pow2(d), Nat.div(Nat.add(n, 7n), 8n),
    Equal.trans(Bool, Nat.is_lt(L.pow2(d), Nat.div(Nat.add(n, 7n), 8n)),
      Nat.is_lt(L.pow2(3n+d), n), False{}, ceil_pow_cmp(d, n),
      N.not_lt_of_le(n, L.pow2(3n+d), h)))

def search_stop(f: Nat, +w: Nat, +d: Nat) ->
  {search(f, False{}, w, d) == d : Nat}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      {==}

def search_fuel(+f: Nat, +more: Bool, +extra: Nat, +w: Nat, +d: Nat,
  +hb: {more == Nat.is_lt(L.pow2(d), w) : Bool},
  +hw: P.le(w, L.pow2(Nat.add(d, f)))) ->
  {search(Nat.add(f, extra), more, w, d) == search(f, more, w, d) : Nat}:
  match f:
    case 0n:
      %Equal.sym(Bool, more, Nat.is_lt(L.pow2(d), w), hb) :
        {search(extra, _, w, d) == d : Nat}
      %Equal.sym(Bool, Nat.is_lt(L.pow2(d), w), False{},
        N.not_lt_of_le(w, L.pow2(d),
          %Equal.sym(Nat, d, Nat.add(d, 0n), P.add_zero(d)) : P.le(w, L.pow2(_))
          hw)) : {search(extra, _, w, d) == d : Nat}
      search_stop(extra, w, d)
    case 1n++p:
      match more:
        case False{}:
          {==}
        case True{}:
          search_fuel(p, Nat.is_lt(L.pow2(1n+d), w), extra, w, 1n+d, {==},
            %Equal.sym(Nat, 1n+Nat.add(d, p), Nat.add(d, 1n+p), P.add_succ(d, p)) :
              P.le(w, L.pow2(_))
            hw)

def search_scaled(+f: Nat, +more: Bool, +n: Nat, +d: Nat) ->
  {3n+search(f, more, Nat.div(Nat.add(n, 7n), 8n), d) == search(f, more, n, 3n+d) : Nat}:
  match f:
    case 0n:
      {==}
    case 1n++p:
      match more:
        case False{}:
          {==}
        case True{}:
          %Equal.sym(Bool, Nat.is_lt(L.pow2(1n+d), Nat.div(Nat.add(n, 7n), 8n)), Nat.is_lt(L.pow2(4n+d), n), ceil_pow_cmp(1n+d, n)) :
            {3n+search(p, _, Nat.div(Nat.add(n, 7n), 8n), 1n+d) == search(p, Nat.is_lt(L.pow2(4n+d), n), n, 4n+d) : Nat}
          search_scaled(p, Nat.is_lt(L.pow2(4n+d), n), n, 1n+d)

def start_three(+n: Nat, +h: P.le(8n, n)) ->
  {search(30n, Nat.is_lt(1n, n), n, 0n) == search(27n, Nat.is_lt(8n, n), n, 3n) : Nat}:
  %Equal.sym(Bool, Nat.is_lt(1n, n), True{},
    N.lt_of_lt_of_le(1n, 8n, n, {==}, h)) :
    {search(30n, _, n, 0n) == search(27n, Nat.is_lt(8n, n), n, 3n) : Nat}
  %Equal.sym(Bool, Nat.is_lt(2n, n), True{},
    N.lt_of_lt_of_le(2n, 8n, n, {==}, h)) :
    {search(29n, _, n, 1n) == search(27n, Nat.is_lt(8n, n), n, 3n) : Nat}
  %Equal.sym(Bool, Nat.is_lt(4n, n), True{},
    N.lt_of_lt_of_le(4n, 8n, n, {==}, h)) :
    {search(28n, _, n, 2n) == search(27n, Nat.is_lt(8n, n), n, 3n) : Nat}
  {==}

# Keep concrete fuel arithmetic outside capacity conversion: https://github.com/bendlang/bend/issues/1071.
def search_initial_fuel(+f: Nat, +extra: Nat, +w: Nat, hw: P.le(w, L.pow2(f))) ->
  {search(Nat.add(f, extra), Nat.is_lt(1n, w), w, 0n) == search(f, Nat.is_lt(1n, w), w, 0n) : Nat}:
  search_fuel(f, Nat.is_lt(1n, w), extra, w, 0n, {==}, hw)

def search_ratio(+n: Nat, +h: P.le(n, L.pow2(30n)), +h8: P.le(8n, n)) ->
  {3n+search(30n, Nat.is_lt(1n, Nat.div(Nat.add(n, 7n), 8n)), Nat.div(Nat.add(n, 7n), 8n), 0n) == search(30n, Nat.is_lt(1n, n), n, 0n) : Nat}:
  %Equal.sym(Nat, search(30n, Nat.is_lt(1n, n), n, 0n), search(27n, Nat.is_lt(8n, n), n, 3n), start_three(n, h8)) :
    {3n+search(30n, Nat.is_lt(1n, Nat.div(Nat.add(n, 7n), 8n)), Nat.div(Nat.add(n, 7n), 8n), 0n) == _ : Nat}
  %Equal.sym(Nat,
    search(30n, Nat.is_lt(1n, Nat.div(Nat.add(n, 7n), 8n)), Nat.div(Nat.add(n, 7n), 8n), 0n),
    search(27n, Nat.is_lt(1n, Nat.div(Nat.add(n, 7n), 8n)), Nat.div(Nat.add(n, 7n), 8n), 0n),
    search_initial_fuel(27n, 3n, Nat.div(Nat.add(n, 7n), 8n), ceil_pow_bound(27n, n, h))) :
    {3n+_ == search(27n, Nat.is_lt(8n, n), n, 3n) : Nat}
  %Equal.sym(Bool, Nat.is_lt(1n, Nat.div(Nat.add(n, 7n), 8n)), Nat.is_lt(8n, n), ceil_pow_cmp(0n, n)) :
    {3n+search(27n, _, Nat.div(Nat.add(n, 7n), 8n), 0n) == search(27n, Nat.is_lt(8n, n), n, 3n) : Nat}
  search_scaled(27n, Nat.is_lt(8n, n), n, 0n)

def depth_ratio(+n: U32, +c: U32,
  +hc: {U32.to_nat(c) == Nat.div(Nat.add(U32.to_nat(n), 7n), 8n) : Nat},
  +hn: P.le(U32.to_nat(n), L.pow2(30n)),
  +h8: P.le(8n, U32.to_nat(n))) ->
  {3n+Bytes.depth(c) == Bytes.depth(n) : Nat}:
  +hcb = P.le_trans(U32.to_nat(c), L.pow2(27n), L.pow2(30n),
    %Equal.sym(Nat, U32.to_nat(c), Nat.div(Nat.add(U32.to_nat(n), 7n), 8n), hc) :
      P.le(_, L.pow2(27n))
    ceil_pow_bound(27n, U32.to_nat(n), hn),
    pow_le(27n, 30n, {==}))
  %Equal.sym(Nat, Bytes.depth(c), search(30n, Nat.is_lt(1n, U32.to_nat(c)), U32.to_nat(c), 0n), depth_model(c, hcb)) :
    {3n+_ == Bytes.depth(n) : Nat}
  %Equal.sym(Nat, Bytes.depth(n), search(30n, Nat.is_lt(1n, U32.to_nat(n)), U32.to_nat(n), 0n), depth_model(n, hn)) :
    {3n+search(30n, Nat.is_lt(1n, U32.to_nat(c)), U32.to_nat(c), 0n) == _ : Nat}
  %Equal.sym(Nat, U32.to_nat(c), Nat.div(Nat.add(U32.to_nat(n), 7n), 8n), hc) :
    {3n+search(30n, Nat.is_lt(1n, _), _, 0n) == search(30n, Nat.is_lt(1n, U32.to_nat(n)), U32.to_nat(n), 0n) : Nat}
  search_ratio(U32.to_nat(n), hn, h8)

def capacity_scale(+d: Nat) ->
  {Nat.pow(2n, 3n+d) == Nat.mul(8n, Nat.pow(2n, d)) : Nat}:
  %pow_bridge(3n+d) : {_ == Nat.mul(8n, Nat.pow(2n, d)) : Nat}
  %pow_bridge(d) : {L.pow2(3n+d) == Nat.mul(8n, _) : Nat}
  Equal.trans(Nat, L.pow2(3n+d), Nat.mul(L.pow2(d), 8n), Nat.mul(8n, L.pow2(d)),
    Equal.sym(Nat, Nat.mul(L.pow2(d), 8n), L.pow2(3n+d), pow8(d)),
    N.mul_comm(L.pow2(d), 8n))

# Convert inequalities before substituting powers: https://github.com/bendlang/bend/issues/1071.
def weaken_lt(+a: Nat, +b: Nat, h: P.lt(a, b)) -> P.le(a, b):
  N.le_of_lt(a, b, h)

def cell_count_bound(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  P.le(U32.to_nat(A.cells(len)), L.pow2(30n)):
  P.le_trans(U32.to_nat(A.cells(len)), L.pow2(27n), L.pow2(30n),
    %Equal.sym(Nat, U32.to_nat(A.cells(len)), Nat.div(Nat.add(U32.to_nat(len), 7n), 8n), Layout.cells_nat(len, h)) :
      P.le(_, L.pow2(27n))
    ceil_pow_bound(27n, U32.to_nat(len), weaken_lt(U32.to_nat(len), L.pow2(30n), h)),
    pow_le(27n, 30n, {==}))

def word_count_bound(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  P.le(U32.to_nat(Bytes.words((len << 2n : U32))), L.pow2(30n)):
  %Equal.sym(Nat, U32.to_nat(Bytes.words((len << 2n : U32))), U32.to_nat(len), Layout.words_nat(len, h)) :
    P.le(_, L.pow2(30n))
  weaken_lt(U32.to_nat(len), L.pow2(30n), h)

def cell_depth_bound(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  P.lt(cell_depth(len), 32n):
  depth_bound(A.cells(len), cell_count_bound(len, h))

def word_depth_bound(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  P.lt(word_depth(len), 32n):
  depth_bound(Bytes.words((len << 2n : U32)), word_count_bound(len, h))

def cells_cover(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  P.le(U32.to_nat(A.cells(len)), cell_capacity(len)):
  depth_covers(A.cells(len), cell_count_bound(len, h))

def ceil_cells_cover(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  P.le(Nat.div(Nat.add(U32.to_nat(len), 7n), 8n), cell_capacity(len)):
  %Layout.cells_nat(len, h) : P.le(_, cell_capacity(len))
  cells_cover(len, h)

def words_cover(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  P.le(U32.to_nat(len), word_capacity(len)):
  %Layout.words_nat(len, h) : P.le(_, word_capacity(len))
  depth_covers(Bytes.words((len << 2n : U32)), word_count_bound(len, h))

def word_depth_value(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) ->
  {word_depth(len) == Bytes.depth(len) : Nat}:
  Equal.cong(U32, Nat, x => Bytes.depth(x), Bytes.words((len << 2n : U32)), len,
    L.u32_to_nat_inj(Bytes.words((len << 2n : U32)), len, Layout.words_nat(len, h)))

def capacity_ratio(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n)),
  +h8: P.le(8n, U32.to_nat(len))) ->
  {word_capacity(len) == Nat.mul(8n, cell_capacity(len)) : Nat}:
  %Equal.sym(Nat, word_depth(len), Bytes.depth(len), word_depth_value(len, h)) :
    {Nat.pow(2n, _) == Nat.mul(8n, cell_capacity(len)) : Nat}
  %depth_ratio(len, A.cells(len), Layout.cells_nat(len, h),
    weaken_lt(U32.to_nat(len), L.pow2(30n), h), h8) :
    {Nat.pow(2n, _) == Nat.mul(8n, cell_capacity(len)) : Nat}
  capacity_scale(cell_depth(len))

# The split equality is ordinary address arithmetic, independent of any array.
def scalar_cell_bound_split(+len: U32, +i: U32, +q: Nat, +r: Nat,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hi: P.lt(U32.to_nat(i), U32.to_nat(len)),
  +split: {U32.to_nat(i) == Nat.add(Nat.mul(8n, q), r) : Nat}) ->
  P.lt(q, cell_capacity(len)):
  N.lt_of_lt_of_le(q, Nat.div(Nat.add(U32.to_nat(len), 7n), 8n), cell_capacity(len),
    %Equal.sym(Bool, Nat.is_lt(q, Nat.div(Nat.add(U32.to_nat(len), 7n), 8n)), Nat.is_lt(Nat.mul(q, 8n), U32.to_nat(len)), ceil_cmp(q, U32.to_nat(len))) : {_ == True{} : Bool}
    N.lt_of_le_of_lt(Nat.mul(q, 8n), U32.to_nat(i), U32.to_nat(len),
      %Equal.sym(Nat, U32.to_nat(i), Nat.add(Nat.mul(8n, q), r), split) :
        P.le(Nat.mul(q, 8n), _)
      %N.mul_comm(8n, q) : P.le(_, Nat.add(Nat.mul(8n, q), r))
      N.le_add_right(Nat.mul(8n, q), r),
      hi),
    ceil_cells_cover(len, h))

def scalar_cell_bound(+len: U32, +i: U32,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hi: P.lt(U32.to_nat(i), U32.to_nat(len))) ->
  P.lt(U32.to_nat((i >> 3n : U32)), cell_capacity(len)):
  scalar_cell_bound_split(len, i, U32.to_nat((i >> 3n : U32)), U32.to_nat((i .&. 7 : U32)),
    h, hi, Layout.split3(i))
