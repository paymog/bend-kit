import Base
import ./f32array.bend as A
import ../lemmas/perfect.bend as P
import ../lemmas/array.bend as Arr
import ./codec-model.bend as C
import ./layout-proof.bend as Layout
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import ../lemmas/lemmas.bend as L

type Step is Data:
  Step{index: U32, value: U32}

def Bounds(+d: Nat, xs: List<&2, Step>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case Con{Step{i, v}, t}:
      P.lt(U32.to_nat(i), Nat.pow(2n, d)) & Bounds(d, t)

def writes(xs: List<&2, Step>, a: Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}:
      a
    case Con{Step{i, v}, t}:
      writes(t, Array.set(U32, a, i, v))

def words(xs: List<&2, Step>, l: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      l
    case Con{Step{i, v}, t}:
      words(t, P.upd(U32, 0, l, U32.to_nat(i), v))

def update_capacity(+d: Nat, +l: List<&2, U32>, +i: U32, +v: U32, h: P.le(Nat.pow(2n, d), P.len(U32, 0, l))) -> P.le(Nat.pow(2n, d), P.len(U32, 0, P.upd(U32, 0, l, U32.to_nat(i), v))):
  %Equal.sym(Nat, P.len(U32, 0, P.upd(U32, 0, l, U32.to_nat(i), v)), P.len(U32, 0, l), P.len_upd(U32, 0, l, U32.to_nat(i), v)) : P.le(Nat.pow(2n, d), _)
  h

def writes_model(+xs: List<&2, Step>, +d: Nat, +l: List<&2, U32>, +hd: P.lt(d, 32n), +hl: P.le(Nat.pow(2n, d), P.len(U32, 0, l)), hb: Bounds(d, xs)) -> {writes(xs, P.build(U32, 0, d, l)) == P.build(U32, 0, d, words(xs, l)) : Array<U32>}:
  match xs:
    case Nil{}:
      {==}
    case Con{Step{+i, +v}, +t}:
      match hb:
        case Tuple{+hi, rest}:
          %P.set_r(U32, 0, d, l, i, v, hd, hi, hl) : {writes(t, _) == P.build(U32, 0, d, words(t, P.upd(U32, 0, l, U32.to_nat(i), v))) : Array<U32>}
          writes_model(t, d, P.upd(U32, 0, l, U32.to_nat(i), v), hd, update_capacity(d, l, i, v, hl), rest)

def EightBounds(+d: Nat, +j: U32) -> Type:
  P.lt(U32.to_nat((j + 0 : U32)), Nat.pow(2n, d)) & P.lt(U32.to_nat((j + 1 : U32)), Nat.pow(2n, d)) & P.lt(U32.to_nat((j + 2 : U32)), Nat.pow(2n, d)) & P.lt(U32.to_nat((j + 3 : U32)), Nat.pow(2n, d)) & P.lt(U32.to_nat((j + 4 : U32)), Nat.pow(2n, d)) & P.lt(U32.to_nat((j + 5 : U32)), Nat.pow(2n, d)) & P.lt(U32.to_nat((j + 6 : U32)), Nat.pow(2n, d)) & P.lt(U32.to_nat((j + 7 : U32)), Nat.pow(2n, d)) & Unit

def TailBounds(+d: Nat, n: Nat, +j: U32) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      P.lt(U32.to_nat(j), Nat.pow(2n, d)) & TailBounds(d, p, (j + 1 : U32))

def EncodeBounds(+d: Nat, n: Nat, +k: U32, +i: U32) -> Type:
  match n:
    case 0n:
      TailBounds(d, U32.to_nat(k), (i << 3n : U32))
    case 1n+p:
      EightBounds(d, (i << 3n : U32)) & EncodeBounds(d, p, k, (i + 1 : U32))

def DecodeBounds(+dw: Nat, +dc: Nat, n: Nat, +i: U32) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      EightBounds(dw, (i << 3n : U32)) & P.lt(U32.to_nat(i), Nat.pow(2n, dc)) & DecodeBounds(dw, dc, p, (i + 1 : U32))

def ListBounds(+d: Nat, n: Nat, +i: U32) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      P.lt(U32.to_nat((i >> 3n : U32)), Nat.pow(2n, d)) & ListBounds(d, p, (i - 1 : U32))

def cell_steps(~enc: F32 -> U32, c: A.Cell, +j: U32) -> List<&2, Step>:
  A.Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  [Step{(j + 0 : U32), enc(v0)}, Step{(j + 1 : U32), enc(v1)}, Step{(j + 2 : U32), enc(v2)}, Step{(j + 3 : U32), enc(v3)}, Step{(j + 4 : U32), enc(v4)}, Step{(j + 5 : U32), enc(v5)}, Step{(j + 6 : U32), enc(v6)}, Step{(j + 7 : U32), enc(v7)}]

def cell_bounds(~enc: F32 -> U32, +c: A.Cell, +d: Nat, +j: U32, h: EightBounds(d, j)) -> Bounds(d, cell_steps(~enc, c, j)):
  match c:
    case A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}:
      match h:
        case Tuple{h0, Tuple{h1, Tuple{h2, Tuple{h3, Tuple{h4, Tuple{h5, Tuple{h6, Tuple{h7, u}}}}}}}}:
          (h0, h1, h2, h3, h4, h5, h6, h7, Unit{})

def cell_actual(~enc: F32 -> U32, c: A.Cell, a: Array<U32>, +j: U32) -> {A.to.cell(~enc, c, a, j) == writes(cell_steps(~enc, c, j), a) : Array<U32>}:
  match c:
    case A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}:
      {==}

def cell_words(~enc: F32 -> U32, c: A.Cell, +l: List<&2, U32>, +j: U32) -> {words(cell_steps(~enc, c, j), l) == C.cell(~enc, c, l, j) : List<&2, U32>}:
  match c:
    case A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}:
      {==}

def to_cell_model(~enc: F32 -> U32, +c: A.Cell, +d: Nat, +l: List<&2, U32>, +j: U32, +hd: P.lt(d, 32n), +hl: P.le(Nat.pow(2n, d), P.len(U32, 0, l)), hb: EightBounds(d, j)) -> {A.to.cell(~enc, c, P.build(U32, 0, d, l), j) == P.build(U32, 0, d, C.cell(~enc, c, l, j)) : Array<U32>}:
  %Equal.sym(Array<U32>, A.to.cell(~enc, c, P.build(U32, 0, d, l), j), writes(cell_steps(~enc, c, j), P.build(U32, 0, d, l)), cell_actual(~enc, c, P.build(U32, 0, d, l), j)) : {_ == P.build(U32, 0, d, C.cell(~enc, c, l, j)) : Array<U32>}
  %cell_words(~enc, c, l, j) : {writes(cell_steps(~enc, c, j), P.build(U32, 0, d, l)) == P.build(U32, 0, d, _) : Array<U32>}
  writes_model(cell_steps(~enc, c, j), d, l, hd, hl, cell_bounds(~enc, c, d, j, hb))

def to_tail_model(~enc: F32 -> U32, +n: Nat, +c: A.Cell, +d: Nat, +l: List<&2, U32>, +j: U32, +k: U32, +hd: P.lt(d, 32n), +hl: P.le(Nat.pow(2n, d), P.len(U32, 0, l)), hb: TailBounds(d, n, j)) -> {A.to.tail(~enc, n, c, P.build(U32, 0, d, l), j, k) == P.build(U32, 0, d, C.tail(~enc, n, c, l, j, k)) : Array<U32>}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      match hb:
        case Tuple{+hi, rest}:
          %P.set_r(U32, 0, d, l, j, enc(A.lane(c, k)), hd, hi, hl) : {A.to.tail(~enc, p, c, _, (j + 1 : U32), (k + 1 : U32)) == P.build(U32, 0, d, C.tail(~enc, p, c, P.upd(U32, 0, l, U32.to_nat(j), enc(A.lane(c, k))), (j + 1 : U32), (k + 1 : U32))) : Array<U32>}
          to_tail_model(~enc, p, c, d, P.upd(U32, 0, l, U32.to_nat(j), enc(A.lane(c, k))), (j + 1 : U32), (k + 1 : U32), hd, update_capacity(d, l, j, enc(A.lane(c, k)), hl), rest)

def cell_capacity(~enc: F32 -> U32, +c: A.Cell, +d: Nat, +l: List<&2, U32>, +j: U32, h: P.le(Nat.pow(2n, d), P.len(U32, 0, l))) -> P.le(Nat.pow(2n, d), P.len(U32, 0, C.cell(~enc, c, l, j))):
  %Equal.sym(Nat, P.len(U32, 0, C.cell(~enc, c, l, j)), P.len(U32, 0, l), C.cell_length(~enc, c, l, j)) : P.le(Nat.pow(2n, d), _)
  h

def to_go_model(~enc: F32 -> U32, +n: Nat, +k: U32, +src: Arr.Tree<A.Cell>, +c: A.Cell, +d: Nat, +l: List<&2, U32>, +i: U32, +hd: P.lt(d, 32n), +hl: P.le(Nat.pow(2n, d), P.len(U32, 0, l)), hb: EncodeBounds(d, n, k, i)) -> {A.to.go(~enc, n, k, (Arr.reify(A.Cell, src), c), P.build(U32, 0, d, l), i) == (Arr.reify(A.Cell, src), P.build(U32, 0, d, C.to_go(~enc, n, k, src, c, l, i))) : Array<A.Cell> & Array<U32>}:
  match n:
    case 0n:
      Equal.cong(Array<U32>, Array<A.Cell> & Array<U32>, w => (Arr.reify(A.Cell, src), w), A.to.tail(~enc, U32.to_nat(k), c, P.build(U32, 0, d, l), (i << 3n : U32), 0), P.build(U32, 0, d, C.tail(~enc, U32.to_nat(k), c, l, (i << 3n : U32), 0)), to_tail_model(~enc, U32.to_nat(k), c, d, l, (i << 3n : U32), 0, hd, hl, hb))
    case 1n++p:
      match hb:
        case Tuple{first, rest}:
          %Arr.tree_get(A.Cell, src, (i + 1 : U32)) : {A.to.go(~enc, p, k, _, A.to.cell(~enc, c, P.build(U32, 0, d, l), (i << 3n : U32)), (i + 1 : U32)) == (Arr.reify(A.Cell, src), P.build(U32, 0, d, C.to_go(~enc, p, k, src, Arr.read(A.Cell, src, (i + 1 : U32)), C.cell(~enc, c, l, (i << 3n : U32)), (i + 1 : U32)))) : Array<A.Cell> & Array<U32>}
          %Equal.sym(Array<U32>, A.to.cell(~enc, c, P.build(U32, 0, d, l), (i << 3n : U32)), P.build(U32, 0, d, C.cell(~enc, c, l, (i << 3n : U32))), to_cell_model(~enc, c, d, l, (i << 3n : U32), hd, hl, first)) : {A.to.go(~enc, p, k, (Arr.reify(A.Cell, src), Arr.read(A.Cell, src, (i + 1 : U32))), _, (i + 1 : U32)) == (Arr.reify(A.Cell, src), P.build(U32, 0, d, C.to_go(~enc, p, k, src, Arr.read(A.Cell, src, (i + 1 : U32)), C.cell(~enc, c, l, (i << 3n : U32)), (i + 1 : U32)))) : Array<A.Cell> & Array<U32>}
          to_go_model(~enc, p, k, src, Arr.read(A.Cell, src, (i + 1 : U32)), d, C.cell(~enc, c, l, (i << 3n : U32)), (i + 1 : U32), hd, cell_capacity(~enc, c, d, l, (i << 3n : U32), hl), rest)

def from_c0_model(~dec: U32 -> F32, +d: Nat, +w: List<&2, U32>, +j: U32, +x0: U32, +hd: P.lt(d, 32n), hb: EightBounds(d, j)) -> {A.from.c0(~dec, j, (P.build(U32, 0, d, w), x0)) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}:
  match hb:
    case Tuple{h0, Tuple{+h1, Tuple{+h2, Tuple{+h3, Tuple{+h4, Tuple{+h5, Tuple{+h6, Tuple{+h7, u}}}}}}}}:
      %P.get_r(U32, 0, d, w, (j + 1 : U32), hd, h1) : {A.from.c1(~dec, j, _, x0) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}
      %P.get_r(U32, 0, d, w, (j + 2 : U32), hd, h2) : {A.from.c2(~dec, j, _, x0, P.nth(U32, 0, w, U32.to_nat((j + 1 : U32)))) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}
      %P.get_r(U32, 0, d, w, (j + 3 : U32), hd, h3) : {A.from.c3(~dec, j, _, x0, P.nth(U32, 0, w, U32.to_nat((j + 1 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 2 : U32)))) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}
      %P.get_r(U32, 0, d, w, (j + 4 : U32), hd, h4) : {A.from.c4(~dec, j, _, x0, P.nth(U32, 0, w, U32.to_nat((j + 1 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 2 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 3 : U32)))) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}
      %P.get_r(U32, 0, d, w, (j + 5 : U32), hd, h5) : {A.from.c5(~dec, j, _, x0, P.nth(U32, 0, w, U32.to_nat((j + 1 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 2 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 3 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 4 : U32)))) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}
      %P.get_r(U32, 0, d, w, (j + 6 : U32), hd, h6) : {A.from.c6(~dec, j, _, x0, P.nth(U32, 0, w, U32.to_nat((j + 1 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 2 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 3 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 4 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 5 : U32)))) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}
      %P.get_r(U32, 0, d, w, (j + 7 : U32), hd, h7) : {A.from.c7(~dec, j, _, x0, P.nth(U32, 0, w, U32.to_nat((j + 1 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 2 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 3 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 4 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 5 : U32))), P.nth(U32, 0, w, U32.to_nat((j + 6 : U32)))) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, x0)) : Array<U32> & A.Cell}
      {==}

def zero_bound(+d: Nat, +i: U32, h: P.lt(U32.to_nat((i + 0 : U32)), Nat.pow(2n, d))) -> P.lt(U32.to_nat(i), Nat.pow(2n, d)):
  %Layout.add_zero_nat(i) : P.lt(_, Nat.pow(2n, d))
  h

def from_c0_at_model(~dec: U32 -> F32, +d: Nat, +w: List<&2, U32>, +j: U32, +hd: P.lt(d, 32n), hb: EightBounds(d, j)) -> {A.from.c0(~dec, j, Array.get(U32, P.build(U32, 0, d, w), j)) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, P.nth(U32, 0, w, U32.to_nat(j)))) : Array<U32> & A.Cell}:
  match hb:
    case Tuple{+h0, Tuple{+h1, Tuple{+h2, Tuple{+h3, Tuple{+h4, Tuple{+h5, Tuple{+h6, Tuple{+h7, u}}}}}}}}:
      %P.get_r(U32, 0, d, w, j, hd, zero_bound(d, j, h0)) : {A.from.c0(~dec, j, _) == (P.build(U32, 0, d, w), C.from_c0(~dec, w, j, P.nth(U32, 0, w, U32.to_nat(j)))) : Array<U32> & A.Cell}
      from_c0_model(~dec, d, w, j, P.nth(U32, 0, w, U32.to_nat(j)), hd, (h0, h1, h2, h3, h4, h5, h6, h7, Unit{}))

def from_zero(~dec: U32 -> F32, r: Array<U32> & A.Cell, out: Array<A.Cell>, +i: U32) -> {A.from.go(~dec, 0n, r, out, i) == out : Array<A.Cell>}:
  match r:
    case Tuple{w, c}:
      {==}

def update_cell_capacity(+d: Nat, +l: List<&2, A.Cell>, +i: U32, +v: A.Cell, h: P.le(Nat.pow(2n, d), P.len(A.Cell, A.zero(), l))) -> P.le(Nat.pow(2n, d), P.len(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), l, U32.to_nat(i), v))):
  %Equal.sym(Nat, P.len(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), l, U32.to_nat(i), v)), P.len(A.Cell, A.zero(), l), P.len_upd(A.Cell, A.zero(), l, U32.to_nat(i), v)) : P.le(Nat.pow(2n, d), _)
  h

def from_at_model(~dec: U32 -> F32, +n: Nat, +dw: Nat, +dc: Nat, +w: List<&2, U32>, +out: List<&2, A.Cell>, +i: U32, +hdw: P.lt(dw, 32n), +hdc: P.lt(dc, 32n), +hlo: P.le(Nat.pow(2n, dc), P.len(A.Cell, A.zero(), out)), hb: DecodeBounds(dw, dc, n, i)) -> {A.from.go(~dec, n, A.from.c0(~dec, (i << 3n : U32), Array.get(U32, P.build(U32, 0, dw, w), (i << 3n : U32))), P.build(A.Cell, A.zero(), dc, out), i) == P.build(A.Cell, A.zero(), dc, C.from_go(~dec, n, w, C.from_c0(~dec, w, (i << 3n : U32), P.nth(U32, 0, w, U32.to_nat((i << 3n : U32)))), out, i)) : Array<A.Cell>}:
  match n:
    case 0n:
      from_zero(~dec, A.from.c0(~dec, (i << 3n : U32), Array.get(U32, P.build(U32, 0, dw, w), (i << 3n : U32))), P.build(A.Cell, A.zero(), dc, out), i)
    case 1n++p:
      match hb:
        case Tuple{first, Tuple{+hi, rest}}:
          %Equal.sym(Array<U32> & A.Cell, A.from.c0(~dec, (i << 3n : U32), Array.get(U32, P.build(U32, 0, dw, w), (i << 3n : U32))), (P.build(U32, 0, dw, w), C.from_c0(~dec, w, (i << 3n : U32), P.nth(U32, 0, w, U32.to_nat((i << 3n : U32))))), from_c0_at_model(~dec, dw, w, (i << 3n : U32), hdw, first)) : {A.from.go(~dec, 1n+p, _, P.build(A.Cell, A.zero(), dc, out), i) == P.build(A.Cell, A.zero(), dc, C.from_go(~dec, 1n+p, w, C.from_c0(~dec, w, (i << 3n : U32), P.nth(U32, 0, w, U32.to_nat((i << 3n : U32)))), out, i)) : Array<A.Cell>}
          %P.set_r(A.Cell, A.zero(), dc, out, i, C.from_c0(~dec, w, (i << 3n : U32), P.nth(U32, 0, w, U32.to_nat((i << 3n : U32)))), hdc, hi, hlo) : {A.from.go(~dec, p, A.from.c0(~dec, ((i + 1 : U32) << 3n : U32), Array.get(U32, P.build(U32, 0, dw, w), ((i + 1 : U32) << 3n : U32))), _, (i + 1 : U32)) == P.build(A.Cell, A.zero(), dc, C.from_go(~dec, p, w, C.from_c0(~dec, w, ((i + 1 : U32) << 3n : U32), P.nth(U32, 0, w, U32.to_nat(((i + 1 : U32) << 3n : U32)))), P.upd(A.Cell, A.zero(), out, U32.to_nat(i), C.from_c0(~dec, w, (i << 3n : U32), P.nth(U32, 0, w, U32.to_nat((i << 3n : U32))))), (i + 1 : U32))) : Array<A.Cell>}
          from_at_model(~dec, p, dw, dc, w, P.upd(A.Cell, A.zero(), out, U32.to_nat(i), C.from_c0(~dec, w, (i << 3n : U32), P.nth(U32, 0, w, U32.to_nat((i << 3n : U32))))), (i + 1 : U32), hdw, hdc, update_cell_capacity(dc, out, i, C.from_c0(~dec, w, (i << 3n : U32), P.nth(U32, 0, w, U32.to_nat((i << 3n : U32)))), hlo), rest)

def peek_model(+d: Nat, +out: List<&2, A.Cell>, +i: U32, +hd: P.lt(d, 32n), hi: P.lt(U32.to_nat((i >> 3n : U32)), Nat.pow(2n, d))) -> {A.peek(P.build(A.Cell, A.zero(), d, out), i) == (P.build(A.Cell, A.zero(), d, out), C.peek(out, i)) : Array<A.Cell> & F32}:
  %P.get_r(A.Cell, A.zero(), d, out, (i >> 3n : U32), hd, hi) : {A.peek.of((i .&. 7 : U32), _) == (P.build(A.Cell, A.zero(), d, out), C.peek(out, i)) : Array<A.Cell> & F32}
  {==}

def source_peek_model(+src: Arr.Tree<A.Cell>, +i: U32) -> {A.peek(Arr.reify(A.Cell, src), i) == (Arr.reify(A.Cell, src), C.source_peek(src, i)) : Array<A.Cell> & F32}:
  %Arr.tree_get(A.Cell, src, (i >> 3n : U32)) : {A.peek.of((i .&. 7 : U32), _) == (Arr.reify(A.Cell, src), C.source_peek(src, i)) : Array<A.Cell> & F32}
  {==}

def list_zero(r: Array<A.Cell> & F32, +i: U32, acc: List<&2, F32>) -> {A.to_list.go(0n, r, i, acc) == acc : List<&2, F32>}:
  match r:
    case Tuple{a, v}:
      {==}

def list_at_model(+n: Nat, +d: Nat, +out: List<&2, A.Cell>, +i: U32, +acc: List<&2, F32>, +hd: P.lt(d, 32n), hb: ListBounds(d, n, i)) -> {A.to_list.go(n, A.peek(P.build(A.Cell, A.zero(), d, out), i), i, acc) == C.list_go(n, out, C.peek(out, i), i, acc) : List<&2, F32>}:
  match n:
    case 0n:
      list_zero(A.peek(P.build(A.Cell, A.zero(), d, out), i), i, acc)
    case 1n++p:
      match hb:
        case Tuple{+hi, rest}:
          %Equal.sym(Array<A.Cell> & F32, A.peek(P.build(A.Cell, A.zero(), d, out), i), (P.build(A.Cell, A.zero(), d, out), C.peek(out, i)), peek_model(d, out, i, hd, hi)) : {A.to_list.go(1n+p, _, i, acc) == C.list_go(1n+p, out, C.peek(out, i), i, acc) : List<&2, F32>}
          list_at_model(p, d, out, (i - 1 : U32), Con{C.peek(out, i), acc}, hd, rest)

def source_at_model(+n: Nat, +src: Arr.Tree<A.Cell>, +i: U32, +acc: List<&2, F32>) -> {A.to_list.go(n, A.peek(Arr.reify(A.Cell, src), i), i, acc) == C.source_list_go(n, src, C.source_peek(src, i), i, acc) : List<&2, F32>}:
  match n:
    case 0n:
      list_zero(A.peek(Arr.reify(A.Cell, src), i), i, acc)
    case 1n++p:
      %Equal.sym(Array<A.Cell> & F32, A.peek(Arr.reify(A.Cell, src), i), (Arr.reify(A.Cell, src), C.source_peek(src, i)), source_peek_model(src, i)) : {A.to_list.go(1n+p, _, i, acc) == C.source_list_go(1n+p, src, C.source_peek(src, i), i, acc) : List<&2, F32>}
      source_at_model(p, src, (i - 1 : U32), Con{C.source_peek(src, i), acc})

def to_list_model(+len: U32, +d: Nat, +out: List<&2, A.Cell>, +hd: P.lt(d, 32n), hb: ListBounds(d, U32.to_nat(len), (len - 1 : U32))) -> {A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, out)}) == C.to_list(len, out) : List<&2, F32>}:
  list_at_model(U32.to_nat(len), d, out, (len - 1 : U32), Nil{}, hd, hb)

def source_list_model(+len: U32, +src: Arr.Tree<A.Cell>) -> {A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)}) == C.source_list(len, src) : List<&2, F32>}:
  source_at_model(U32.to_nat(len), src, (len - 1 : U32), Nil{})

def encode_model(~enc: F32 -> U32, +len: U32, +src: Arr.Tree<A.Cell>, +d: Nat, +w: List<&2, U32>, +hd: P.lt(d, 32n), +hl: P.le(Nat.pow(2n, d), P.len(U32, 0, w)), ha: {Bytes.alloc((len << 2n : U32)) == P.build(U32, 0, d, w) : Array<U32>}, hb: EncodeBounds(d, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0)) -> {A.to_bytes.with(~enc, A.F32Array{len, Arr.reify(A.Cell, src)}) == Bytes.Bytes{(len << 2n : U32), P.build(U32, 0, d, C.encode(~enc, len, src, w))} : Bytes.Bytes}:
  %Equal.sym(Array<U32>, Bytes.alloc((len << 2n : U32)), P.build(U32, 0, d, w), ha) : {A.to.fin((len << 2n : U32), A.to.go(~enc, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), Array.get(A.Cell, Arr.reify(A.Cell, src), 0), _, 0)) == Bytes.Bytes{(len << 2n : U32), P.build(U32, 0, d, C.encode(~enc, len, src, w))} : Bytes.Bytes}
  %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((len << 2n : U32), A.to.go(~enc, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), _, P.build(U32, 0, d, w), 0)) == Bytes.Bytes{(len << 2n : U32), P.build(U32, 0, d, C.encode(~enc, len, src, w))} : Bytes.Bytes}
  %Equal.sym(Array<A.Cell> & Array<U32>, A.to.go(~enc, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), (Arr.reify(A.Cell, src), Arr.read(A.Cell, src, 0)), P.build(U32, 0, d, w), 0), (Arr.reify(A.Cell, src), P.build(U32, 0, d, C.encode(~enc, len, src, w))), to_go_model(~enc, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), src, Arr.read(A.Cell, src, 0), d, w, 0, hd, hl, hb)) : {A.to.fin((len << 2n : U32), _) == Bytes.Bytes{(len << 2n : U32), P.build(U32, 0, d, C.encode(~enc, len, src, w))} : Bytes.Bytes}
  {==}

def decode_model(~dec: U32 -> F32, +len: U32, +dw: Nat, +dc: Nat, +w: List<&2, U32>, +out: List<&2, A.Cell>, +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hdw: P.lt(dw, 32n), +hdc: P.lt(dc, 32n), +hl: P.le(Nat.pow(2n, dc), P.len(A.Cell, A.zero(), out)), ha: {A.alloc(len) == P.build(A.Cell, A.zero(), dc, out) : Array<A.Cell>}, hb: DecodeBounds(dw, dc, U32.to_nat(A.cells(len)), 0)) -> {C.from_bytes(~dec, Bytes.Bytes{(len << 2n : U32), P.build(U32, 0, dw, w)}) == Some{A.F32Array{len, A.trim(P.build(A.Cell, A.zero(), dc, C.decode(~dec, len, w, out)), len)}} : Maybe<&1, A.F32Array>}:
  %Equal.sym(Bool, U32.is_eq(((len << 2n : U32) .&. 3 : U32), 0), True{}, Layout.aligned2(len)) : {A.from_bytes.if(~dec, _, (len << 2n : U32), P.build(U32, 0, dw, w)) == Some{A.F32Array{len, A.trim(P.build(A.Cell, A.zero(), dc, C.decode(~dec, len, w, out)), len)}} : Maybe<&1, A.F32Array>}
  %Equal.sym(U32, ((len << 2n : U32) >> 2n : U32), len, Layout.unshift2(len, h)) : {Some{A.F32Array{_, A.trim(A.from.go(~dec, U32.to_nat(A.cells(_)), A.from.c0(~dec, 0, Array.get(U32, P.build(U32, 0, dw, w), 0)), A.alloc(_), 0), _)}} == Some{A.F32Array{len, A.trim(P.build(A.Cell, A.zero(), dc, C.decode(~dec, len, w, out)), len)}} : Maybe<&1, A.F32Array>}
  %Equal.sym(Array<A.Cell>, A.alloc(len), P.build(A.Cell, A.zero(), dc, out), ha) : {Some{A.F32Array{len, A.trim(A.from.go(~dec, U32.to_nat(A.cells(len)), A.from.c0(~dec, 0, Array.get(U32, P.build(U32, 0, dw, w), 0)), _, 0), len)}} == Some{A.F32Array{len, A.trim(P.build(A.Cell, A.zero(), dc, C.decode(~dec, len, w, out)), len)}} : Maybe<&1, A.F32Array>}
  %Equal.sym(Array<A.Cell>, A.from.go(~dec, U32.to_nat(A.cells(len)), A.from.c0(~dec, 0, Array.get(U32, P.build(U32, 0, dw, w), 0)), P.build(A.Cell, A.zero(), dc, out), 0), P.build(A.Cell, A.zero(), dc, C.decode(~dec, len, w, out)), from_at_model(~dec, U32.to_nat(A.cells(len)), dw, dc, w, out, 0, hdw, hdc, hl, hb)) : {Some{A.F32Array{len, A.trim(_, len)}} == Some{A.F32Array{len, A.trim(P.build(A.Cell, A.zero(), dc, C.decode(~dec, len, w, out)), len)}} : Maybe<&1, A.F32Array>}
  {==}
