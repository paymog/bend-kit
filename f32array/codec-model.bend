# Copyable list memory for the f32 codec; Array bridges use lemmas/perfect.bend.
import Base
import ./f32array.bend as A
import ../lemmas/array.bend as Arr
import ../lemmas/perfect.bend as P
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def from_bytes(~dec: U32 -> F32, b: Bytes.Bytes) -> Maybe<&1, A.F32Array>:
  Bytes.Bytes{+len, buf} = b
  A.from_bytes.if(~dec, U32.is_eq((len .&. 3 : U32), 0), len, buf)

def from_bytes_le(b: Bytes.Bytes) -> {A.from_bytes.le(b) == from_bytes(~A.of_bits, b) : Maybe<&1, A.F32Array>}:
  match b:
    case Bytes.Bytes{len, buf}:
      {==}

def from_bytes_be(b: Bytes.Bytes) -> {A.from_bytes.be(b) == from_bytes(~A.of_bits.be, b) : Maybe<&1, A.F32Array>}:
  match b:
    case Bytes.Bytes{len, buf}:
      {==}

# Keep these addresses and write order identical to A.to.cell.
def cell(~enc: F32 -> U32, c: A.Cell, w: List<&2, U32>, +j: U32) -> List<&2, U32>:
  A.Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, w, U32.to_nat((j + 0 : U32)), enc(v0)), U32.to_nat((j + 1 : U32)), enc(v1)), U32.to_nat((j + 2 : U32)), enc(v2)), U32.to_nat((j + 3 : U32)), enc(v3)), U32.to_nat((j + 4 : U32)), enc(v4)), U32.to_nat((j + 5 : U32)), enc(v5)), U32.to_nat((j + 6 : U32)), enc(v6)), U32.to_nat((j + 7 : U32)), enc(v7))

def tail(~enc: F32 -> U32, n: Nat, +c: A.Cell, w: List<&2, U32>, +j: U32, +l: U32) -> List<&2, U32>:
  match n:
    case 0n:
      w
    case 1n+p:
      tail(~enc, p, c, P.upd(U32, 0, w, U32.to_nat(j), enc(A.lane(c, l))), (j + 1 : U32), (l + 1 : U32))

# c is the current speculative source read, including when n is zero.
def to_go(~enc: F32 -> U32, n: Nat, +k: U32, +src: Arr.Tree<A.Cell>, c: A.Cell, w: List<&2, U32>, +i: U32) -> List<&2, U32>:
  match n:
    case 0n:
      tail(~enc, U32.to_nat(k), c, w, (i << 3n : U32), 0)
    case 1n+p:
      to_go(~enc, p, k, src, Arr.read(A.Cell, src, (i + 1 : U32)), cell(~enc, c, w, (i << 3n : U32)), (i + 1 : U32))

# As in A.from.c0, x0 is the already-read word at j.
def from_c0(~dec: U32 -> F32, +w: List<&2, U32>, +j: U32, x0: U32) -> A.Cell:
  A.Cell{dec(x0), dec(P.nth(U32, 0, w, U32.to_nat((j + 1 : U32)))), dec(P.nth(U32, 0, w, U32.to_nat((j + 2 : U32)))), dec(P.nth(U32, 0, w, U32.to_nat((j + 3 : U32)))), dec(P.nth(U32, 0, w, U32.to_nat((j + 4 : U32)))), dec(P.nth(U32, 0, w, U32.to_nat((j + 5 : U32)))), dec(P.nth(U32, 0, w, U32.to_nat((j + 6 : U32)))), dec(P.nth(U32, 0, w, U32.to_nat((j + 7 : U32))))}

def from_go(~dec: U32 -> F32, n: Nat, +w: List<&2, U32>, c: A.Cell, out: List<&2, A.Cell>, +i: U32) -> List<&2, A.Cell>:
  match n:
    case 0n:
      out
    case 1n+p:
      +j = (i + 1 : U32)
      from_go(~dec, p, w, from_c0(~dec, w, (j << 3n : U32), P.nth(U32, 0, w, U32.to_nat((j << 3n : U32)))), P.upd(A.Cell, A.zero(), out, U32.to_nat(i), c), j)

def source_peek(+src: Arr.Tree<A.Cell>, +i: U32) -> F32:
  A.lane(Arr.read(A.Cell, src, (i >> 3n : U32)), (i .&. 7 : U32))

def peek(+out: List<&2, A.Cell>, +i: U32) -> F32:
  A.lane(P.nth(A.Cell, A.zero(), out, U32.to_nat((i >> 3n : U32))), (i .&. 7 : U32))

def source_list_go(n: Nat, +src: Arr.Tree<A.Cell>, v: F32, +i: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match n:
    case 0n:
      acc
    case 1n+p:
      source_list_go(p, src, source_peek(src, (i - 1 : U32)), (i - 1 : U32), Con{v, acc})

def list_go(n: Nat, +out: List<&2, A.Cell>, v: F32, +i: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match n:
    case 0n:
      acc
    case 1n+p:
      list_go(p, out, peek(out, (i - 1 : U32)), (i - 1 : U32), Con{v, acc})

def source_list(+len: U32, +src: Arr.Tree<A.Cell>) -> List<&2, F32>:
  source_list_go(U32.to_nat(len), src, source_peek(src, (len - 1 : U32)), (len - 1 : U32), Nil{})

def to_list(+len: U32, +out: List<&2, A.Cell>) -> List<&2, F32>:
  list_go(U32.to_nat(len), out, peek(out, (len - 1 : U32)), (len - 1 : U32), Nil{})

# Address traces carry coordinates only, not values or semantic assumptions.
type Write is Data:
  Write{at: Nat, cell: U32, lane: U32}

def append(-T: Data, xs: List<&2, T>, +ys: List<&2, T>) -> List<&2, T>:
  match xs:
    case Nil{}:
      ys
    case Con{x, t}:
      Con{x, append(T, t, ys)}

def cell_trace(+i: U32, +j: U32) -> List<&2, Write>:
  [Write{U32.to_nat((j + 0 : U32)), i, 0}, Write{U32.to_nat((j + 1 : U32)), i, 1}, Write{U32.to_nat((j + 2 : U32)), i, 2}, Write{U32.to_nat((j + 3 : U32)), i, 3}, Write{U32.to_nat((j + 4 : U32)), i, 4}, Write{U32.to_nat((j + 5 : U32)), i, 5}, Write{U32.to_nat((j + 6 : U32)), i, 6}, Write{U32.to_nat((j + 7 : U32)), i, 7}]

def tail_trace(n: Nat, +i: U32, +j: U32, +l: U32) -> List<&2, Write>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{Write{U32.to_nat(j), i, l}, tail_trace(p, i, (j + 1 : U32), (l + 1 : U32))}

def encode_trace(n: Nat, +k: U32, +i: U32) -> List<&2, Write>:
  match n:
    case 0n:
      tail_trace(U32.to_nat(k), i, (i << 3n : U32), 0)
    case 1n+p:
      append(Write, cell_trace(i, (i << 3n : U32)), encode_trace(p, k, (i + 1 : U32)))

def apply(~enc: F32 -> U32, xs: List<&2, Write>, +src: Arr.Tree<A.Cell>, w: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      w
    case Con{Write{at, ci, l}, t}:
      apply(~enc, t, src, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l))))

def apply_append(~enc: F32 -> U32, +xs: List<&2, Write>, +ys: List<&2, Write>, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>) -> {apply(~enc, append(Write, xs, ys), src, w) == apply(~enc, ys, src, apply(~enc, xs, src, w)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case Con{Write{+at, +ci, +l}, +t}:
      apply_append(~enc, t, ys, src, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l))))

def cell_lanes(~enc: F32 -> U32, +c: A.Cell, +w: List<&2, U32>, +j: U32) -> {cell(~enc, c, w, j) == P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, P.upd(U32, 0, w, U32.to_nat((j + 0 : U32)), enc(A.lane(c, 0))), U32.to_nat((j + 1 : U32)), enc(A.lane(c, 1))), U32.to_nat((j + 2 : U32)), enc(A.lane(c, 2))), U32.to_nat((j + 3 : U32)), enc(A.lane(c, 3))), U32.to_nat((j + 4 : U32)), enc(A.lane(c, 4))), U32.to_nat((j + 5 : U32)), enc(A.lane(c, 5))), U32.to_nat((j + 6 : U32)), enc(A.lane(c, 6))), U32.to_nat((j + 7 : U32)), enc(A.lane(c, 7))) : List<&2, U32>}:
  match c:
    case A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}:
      {==}

def tail_apply(~enc: F32 -> U32, +n: Nat, +src: Arr.Tree<A.Cell>, +i: U32, +w: List<&2, U32>, +j: U32, +l: U32) -> {tail(~enc, n, Arr.read(A.Cell, src, i), w, j, l) == apply(~enc, tail_trace(n, i, j, l), src, w) : List<&2, U32>}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      tail_apply(~enc, p, src, i, P.upd(U32, 0, w, U32.to_nat(j), enc(A.lane(Arr.read(A.Cell, src, i), l))), (j + 1 : U32), (l + 1 : U32))

def cell_apply(~enc: F32 -> U32, +src: Arr.Tree<A.Cell>, +i: U32, +w: List<&2, U32>, +j: U32) -> {cell(~enc, Arr.read(A.Cell, src, i), w, j) == apply(~enc, cell_trace(i, j), src, w) : List<&2, U32>}:
  cell_lanes(~enc, Arr.read(A.Cell, src, i), w, j)

def to_go_apply(~enc: F32 -> U32, +n: Nat, +k: U32, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>, +i: U32) -> {to_go(~enc, n, k, src, Arr.read(A.Cell, src, i), w, i) == apply(~enc, encode_trace(n, k, i), src, w) : List<&2, U32>}:
  match n:
    case 0n:
      tail_apply(~enc, U32.to_nat(k), src, i, w, (i << 3n : U32), 0)
    case 1n++p:
      %Equal.sym(List<&2, U32>, to_go(~enc, p, k, src, Arr.read(A.Cell, src, (i + 1 : U32)), cell(~enc, Arr.read(A.Cell, src, i), w, (i << 3n : U32)), (i + 1 : U32)), apply(~enc, encode_trace(p, k, (i + 1 : U32)), src, cell(~enc, Arr.read(A.Cell, src, i), w, (i << 3n : U32))), to_go_apply(~enc, p, k, src, cell(~enc, Arr.read(A.Cell, src, i), w, (i << 3n : U32)), (i + 1 : U32))) : {_ == apply(~enc, encode_trace(1n+p, k, i), src, w) : List<&2, U32>}
      %Equal.sym(List<&2, U32>, cell(~enc, Arr.read(A.Cell, src, i), w, (i << 3n : U32)), apply(~enc, cell_trace(i, (i << 3n : U32)), src, w), cell_apply(~enc, src, i, w, (i << 3n : U32))) : {apply(~enc, encode_trace(p, k, (i + 1 : U32)), src, _) == apply(~enc, encode_trace(1n+p, k, i), src, w) : List<&2, U32>}
      Equal.sym(List<&2, U32>, apply(~enc, encode_trace(1n+p, k, i), src, w), apply(~enc, encode_trace(p, k, (i + 1 : U32)), src, apply(~enc, cell_trace(i, (i << 3n : U32)), src, w)), apply_append(~enc, cell_trace(i, (i << 3n : U32)), encode_trace(p, k, (i + 1 : U32)), src, w))

def nth_upd_ne(-T: Data, +zero: T, +w: List<&2, T>, +i: Nat, +j: Nat, +v: T, +h: {Nat.is_eq(i, j) == False{} : Bool}) -> {P.nth(T, zero, w, i) == P.nth(T, zero, P.upd(T, zero, w, j, v), i) : T}:
  match w:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      match i:
        case 0n:
          match j:
            case 0n:
              P.efq({x == v : T}, P.ft(Equal.sym(Bool, True{}, False{}, h)))
            case 1n+q:
              {==}
        case 1n++p:
          match j:
            case 0n:
              {==}
            case 1n++q:
              nth_upd_ne(T, zero, t, p, q, v, h)

def apply_length(~enc: F32 -> U32, +xs: List<&2, Write>, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>) -> {P.len(U32, 0, apply(~enc, xs, src, w)) == P.len(U32, 0, w) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case Con{Write{+at, +ci, +l}, +t}:
      %Equal.sym(Nat, P.len(U32, 0, apply(~enc, t, src, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l))))), P.len(U32, 0, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l)))), apply_length(~enc, t, src, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l))))) : {_ == P.len(U32, 0, w) : Nat}
      P.len_upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l)))

def Avoid(xs: List<&2, Write>, +x: Nat) -> Type:
  match xs:
    case Nil{}:
      Unit
    case Con{Write{at, ci, l}, t}:
      {Nat.is_eq(x, at) == False{} : Bool} & Avoid(t, x)

def apply_frame(~enc: F32 -> U32, +xs: List<&2, Write>, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>, +x: Nat, h: Avoid(xs, x)) -> {P.nth(U32, 0, w, x) == P.nth(U32, 0, apply(~enc, xs, src, w), x) : U32}:
  match xs:
    case Nil{}:
      {==}
    case Con{Write{+at, +ci, +l}, +t}:
      (ne, rest) = h
      %apply_frame(~enc, t, src, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l))), x, rest) : {P.nth(U32, 0, w, x) == _ : U32}
      nth_upd_ne(U32, 0, w, x, at, enc(A.lane(Arr.read(A.Cell, src, ci), l)), ne)

# p selects a write. Only coordinate equalities and non-aliasing are premises.
def Location(xs: List<&2, Write>, p: Nat, +t: U32, +x: Nat) -> Type:
  match xs:
    case Nil{}:
      Empty
    case Con{Write{at, ci, l}, rest}:
      match p:
        case 0n:
          {at == x : Nat} & ({ci == (t >> 3n : U32) : U32} & ({l == (t .&. 7 : U32) : U32} & Avoid(rest, x)))
        case 1n+q:
          Location(rest, q, t, x)

def apply_at(~enc: F32 -> U32, +xs: List<&2, Write>, +p: Nat, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>, +t: U32, +x: Nat, +cap: P.lt(x, P.len(U32, 0, w)), loc: Location(xs, p, t, x)) -> {enc(source_peek(src, t)) == P.nth(U32, 0, apply(~enc, xs, src, w), x) : U32}:
  match xs:
    case Nil{}:
      P.efq({enc(source_peek(src, t)) == P.nth(U32, 0, apply(~enc, Nil{}, src, w), x) : U32}, loc)
    case Con{Write{+at, +ci, +l}, +rest}:
      match p:
        case 0n:
          (+ea, (+ec, (+el, no))) = loc
          %apply_frame(~enc, rest, src, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l))), x, no) : {enc(source_peek(src, t)) == _ : U32}
          %Equal.sym(Nat, at, x, ea) : {enc(source_peek(src, t)) == P.nth(U32, 0, P.upd(U32, 0, w, _, enc(A.lane(Arr.read(A.Cell, src, ci), l))), x) : U32}
          %Equal.sym(U32, ci, (t >> 3n : U32), ec) : {enc(source_peek(src, t)) == P.nth(U32, 0, P.upd(U32, 0, w, x, enc(A.lane(Arr.read(A.Cell, src, _), l))), x) : U32}
          %Equal.sym(U32, l, (t .&. 7 : U32), el) : {enc(source_peek(src, t)) == P.nth(U32, 0, P.upd(U32, 0, w, x, enc(A.lane(Arr.read(A.Cell, src, (t >> 3n : U32)), _))), x) : U32}
          P.nth_upd_same(U32, 0, w, x, enc(source_peek(src, t)), cap)
        case 1n++q:
          apply_at(~enc, rest, q, src, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l))), t, x,
            (%Equal.sym(Nat, P.len(U32, 0, P.upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l)))), P.len(U32, 0, w), P.len_upd(U32, 0, w, at, enc(A.lane(Arr.read(A.Cell, src, ci), l)))) : P.lt(x, _)
             cap), loc)

def encoded_at(~enc: F32 -> U32, +n: Nat, +k: U32, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>, +i: U32, +p: Nat, +t: U32, +x: Nat, +cap: P.lt(x, P.len(U32, 0, w)), loc: Location(encode_trace(n, k, i), p, t, x)) -> {enc(source_peek(src, t)) == P.nth(U32, 0, to_go(~enc, n, k, src, Arr.read(A.Cell, src, i), w, i), x) : U32}:
  %Equal.sym(List<&2, U32>, to_go(~enc, n, k, src, Arr.read(A.Cell, src, i), w, i), apply(~enc, encode_trace(n, k, i), src, w), to_go_apply(~enc, n, k, src, w, i)) : {enc(source_peek(src, t)) == P.nth(U32, 0, _, x) : U32}
  apply_at(~enc, encode_trace(n, k, i), p, src, w, t, x, cap, loc)

type ReadWrite is Data:
  ReadWrite{at: Nat, word: U32}

def decode_trace(n: Nat, +i: U32) -> List<&2, ReadWrite>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{ReadWrite{U32.to_nat(i), (i << 3n : U32)}, decode_trace(p, (i + 1 : U32))}

def read_cell(~dec: U32 -> F32, +w: List<&2, U32>, +j: U32) -> A.Cell:
  from_c0(~dec, w, j, P.nth(U32, 0, w, U32.to_nat(j)))

def apply_dec(~dec: U32 -> F32, xs: List<&2, ReadWrite>, +w: List<&2, U32>, out: List<&2, A.Cell>) -> List<&2, A.Cell>:
  match xs:
    case Nil{}:
      out
    case Con{ReadWrite{at, j}, rest}:
      apply_dec(~dec, rest, w, P.upd(A.Cell, A.zero(), out, at, read_cell(~dec, w, j)))

def from_go_apply(~dec: U32 -> F32, +n: Nat, +w: List<&2, U32>, +out: List<&2, A.Cell>, +i: U32) -> {from_go(~dec, n, w, read_cell(~dec, w, (i << 3n : U32)), out, i) == apply_dec(~dec, decode_trace(n, i), w, out) : List<&2, A.Cell>}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      from_go_apply(~dec, p, w, P.upd(A.Cell, A.zero(), out, U32.to_nat(i), read_cell(~dec, w, (i << 3n : U32))), (i + 1 : U32))

def DecAvoid(xs: List<&2, ReadWrite>, +x: Nat) -> Type:
  match xs:
    case Nil{}:
      Unit
    case Con{ReadWrite{at, j}, rest}:
      {Nat.is_eq(x, at) == False{} : Bool} & DecAvoid(rest, x)

def apply_dec_frame(~dec: U32 -> F32, +xs: List<&2, ReadWrite>, +w: List<&2, U32>, +out: List<&2, A.Cell>, +x: Nat, h: DecAvoid(xs, x)) -> {P.nth(A.Cell, A.zero(), out, x) == P.nth(A.Cell, A.zero(), apply_dec(~dec, xs, w, out), x) : A.Cell}:
  match xs:
    case Nil{}:
      {==}
    case Con{ReadWrite{+at, +j}, +rest}:
      (ne, no) = h
      %apply_dec_frame(~dec, rest, w, P.upd(A.Cell, A.zero(), out, at, read_cell(~dec, w, j)), x, no) : {P.nth(A.Cell, A.zero(), out, x) == _ : A.Cell}
      nth_upd_ne(A.Cell, A.zero(), out, x, at, read_cell(~dec, w, j), ne)

# Lane zero uses the incoming read at j, not the expression j+0.
def read_address(+j: U32, k: Nat) -> Nat:
  match k:
    case 0n:
      U32.to_nat(j)
    case 1n:
      U32.to_nat((j + 1 : U32))
    case 2n:
      U32.to_nat((j + 2 : U32))
    case 3n:
      U32.to_nat((j + 3 : U32))
    case 4n:
      U32.to_nat((j + 4 : U32))
    case 5n:
      U32.to_nat((j + 5 : U32))
    case 6n:
      U32.to_nat((j + 6 : U32))
    case 7n+p:
      U32.to_nat((j + 7 : U32))

def read_lane(~dec: U32 -> F32, +w: List<&2, U32>, +j: U32, +k: Nat, +h: P.lt(k, 8n)) -> {A.lane(read_cell(~dec, w, j), U32.from_nat(k)) == dec(P.nth(U32, 0, w, read_address(j, k))) : F32}:
  match k:
    case 0n:
      {==}
    case 1n:
      {==}
    case 2n:
      {==}
    case 3n:
      {==}
    case 4n:
      {==}
    case 5n:
      {==}
    case 6n:
      {==}
    case 7n:
      {==}
    case 8n+p:
      P.efq({A.lane(read_cell(~dec, w, j), U32.from_nat(8n+p)) == dec(P.nth(U32, 0, w, read_address(j, 8n+p))) : F32}, P.lt_zero(p, h))

def DecLocation(xs: List<&2, ReadWrite>, p: Nat, +t: U32, +x: Nat, +k: Nat) -> Type:
  match xs:
    case Nil{}:
      Empty
    case Con{ReadWrite{at, j}, rest}:
      match p:
        case 0n:
          {at == U32.to_nat((t >> 3n : U32)) : Nat} & (P.lt(k, 8n) & ({U32.from_nat(k) == (t .&. 7 : U32) : U32} & ({read_address(j, k) == x : Nat} & DecAvoid(rest, U32.to_nat((t >> 3n : U32))))))
        case 1n+q:
          DecLocation(rest, q, t, x, k)

def read_lane_at(~dec: U32 -> F32, +w: List<&2, U32>, +j: U32, +t: U32, +x: Nat, +k: Nat, +hk: P.lt(k, 8n), el: {U32.from_nat(k) == (t .&. 7 : U32) : U32}, ea: {read_address(j, k) == x : Nat}) -> {dec(P.nth(U32, 0, w, x)) == A.lane(read_cell(~dec, w, j), (t .&. 7 : U32)) : F32}:
  %el : {dec(P.nth(U32, 0, w, x)) == A.lane(read_cell(~dec, w, j), _) : F32}
  %ea : {dec(P.nth(U32, 0, w, _)) == A.lane(read_cell(~dec, w, j), U32.from_nat(k)) : F32}
  Equal.sym(F32, A.lane(read_cell(~dec, w, j), U32.from_nat(k)), dec(P.nth(U32, 0, w, read_address(j, k))), read_lane(~dec, w, j, k, hk))

def lane_written(+out: List<&2, A.Cell>, +at: Nat, +c: A.Cell, +l: U32, +cap: P.lt(at, P.len(A.Cell, A.zero(), out))) -> {A.lane(c, l) == A.lane(P.nth(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), out, at, c), at), l) : F32}:
  Equal.cong(A.Cell, F32, x => A.lane(x, l), c, P.nth(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), out, at, c), at), P.nth_upd_same(A.Cell, A.zero(), out, at, c, cap))

def apply_dec_at(~dec: U32 -> F32, +xs: List<&2, ReadWrite>, +p: Nat, +w: List<&2, U32>, +out: List<&2, A.Cell>, +t: U32, +x: Nat, +k: Nat, +cap: P.lt(U32.to_nat((t >> 3n : U32)), P.len(A.Cell, A.zero(), out)), loc: DecLocation(xs, p, t, x, k)) -> {dec(P.nth(U32, 0, w, x)) == peek(apply_dec(~dec, xs, w, out), t) : F32}:
  match xs:
    case Nil{}:
      P.efq({dec(P.nth(U32, 0, w, x)) == peek(apply_dec(~dec, Nil{}, w, out), t) : F32}, loc)
    case Con{ReadWrite{+at, +j}, +rest}:
      match p:
        case 0n:
          (+ea, (+hk, (el, (ex, no)))) = loc
          %apply_dec_frame(~dec, rest, w, P.upd(A.Cell, A.zero(), out, at, read_cell(~dec, w, j)), U32.to_nat((t >> 3n : U32)), no) : {dec(P.nth(U32, 0, w, x)) == A.lane(_, (t .&. 7 : U32)) : F32}
          %Equal.sym(Nat, at, U32.to_nat((t >> 3n : U32)), ea) : {dec(P.nth(U32, 0, w, x)) == A.lane(P.nth(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), out, _, read_cell(~dec, w, j)), U32.to_nat((t >> 3n : U32))), (t .&. 7 : U32)) : F32}
          Equal.trans(F32, dec(P.nth(U32, 0, w, x)), A.lane(read_cell(~dec, w, j), (t .&. 7 : U32)), A.lane(P.nth(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), out, U32.to_nat((t >> 3n : U32)), read_cell(~dec, w, j)), U32.to_nat((t >> 3n : U32))), (t .&. 7 : U32)),
            read_lane_at(~dec, w, j, t, x, k, hk, el, ex),
            lane_written(out, U32.to_nat((t >> 3n : U32)), read_cell(~dec, w, j), (t .&. 7 : U32), cap))
        case 1n++q:
          apply_dec_at(~dec, rest, q, w, P.upd(A.Cell, A.zero(), out, at, read_cell(~dec, w, j)), t, x, k,
            (%Equal.sym(Nat, P.len(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), out, at, read_cell(~dec, w, j))), P.len(A.Cell, A.zero(), out), P.len_upd(A.Cell, A.zero(), out, at, read_cell(~dec, w, j))) : P.lt(U32.to_nat((t >> 3n : U32)), _)
             cap), loc)

def decoded_at(~dec: U32 -> F32, +n: Nat, +w: List<&2, U32>, +out: List<&2, A.Cell>, +i: U32, +p: Nat, +t: U32, +x: Nat, +k: Nat, +cap: P.lt(U32.to_nat((t >> 3n : U32)), P.len(A.Cell, A.zero(), out)), loc: DecLocation(decode_trace(n, i), p, t, x, k)) -> {dec(P.nth(U32, 0, w, x)) == peek(from_go(~dec, n, w, read_cell(~dec, w, (i << 3n : U32)), out, i), t) : F32}:
  %Equal.sym(List<&2, A.Cell>, from_go(~dec, n, w, read_cell(~dec, w, (i << 3n : U32)), out, i), apply_dec(~dec, decode_trace(n, i), w, out), from_go_apply(~dec, n, w, out, i)) : {dec(P.nth(U32, 0, w, x)) == peek(_, t) : F32}
  apply_dec_at(~dec, decode_trace(n, i), p, w, out, t, x, k, cap, loc)

def bits_roundtrip(v: F32) -> {A.of_bits(A.to_bits(v)) == v : F32}:
  match v:
    case F32{w}:
      {==}

def encode(~enc: F32 -> U32, +len: U32, +src: Arr.Tree<A.Cell>, w: List<&2, U32>) -> List<&2, U32>:
  to_go(~enc, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), src, Arr.read(A.Cell, src, 0), w, 0)

def decode(~dec: U32 -> F32, +len: U32, +w: List<&2, U32>, out: List<&2, A.Cell>) -> List<&2, A.Cell>:
  from_go(~dec, U32.to_nat(A.cells(len)), w, read_cell(~dec, w, 0), out, 0)

def EncodeLocation(+len: U32, +p: Nat, +t: U32, +x: Nat) -> Type:
  Location(encode_trace(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0), p, t, x)

def DecodeLocation(+len: U32, +p: Nat, +t: U32, +x: Nat, +k: Nat) -> Type:
  DecLocation(decode_trace(U32.to_nat(A.cells(len)), 0), p, t, x, k)

# Every F32 payload is structural, including every NaN bit pattern.
def roundtrip_at(~enc: F32 -> U32, ~dec: U32 -> F32, ~rt: @v:F32 -> {dec(enc(v)) == v : F32}, +len: U32, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>, +out: List<&2, A.Cell>, +t: U32, +x: Nat, +ep: Nat, +dp: Nat, +k: Nat, +hw: P.lt(x, P.len(U32, 0, w)), +hc: P.lt(U32.to_nat((t >> 3n : U32)), P.len(A.Cell, A.zero(), out)), he: EncodeLocation(len, ep, t, x), hd: DecodeLocation(len, dp, t, x, k)) -> {source_peek(src, t) == peek(decode(~dec, len, encode(~enc, len, src, w), out), t) : F32}:
  %rt(source_peek(src, t)) : {_ == peek(decode(~dec, len, encode(~enc, len, src, w), out), t) : F32}
  %Equal.sym(U32, enc(source_peek(src, t)), P.nth(U32, 0, encode(~enc, len, src, w), x), encoded_at(~enc, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), src, w, 0, ep, t, x, hw, he)) : {dec(_) == peek(decode(~dec, len, encode(~enc, len, src, w), out), t) : F32}
  decoded_at(~dec, U32.to_nat(A.cells(len)), encode(~enc, len, src, w), out, 0, dp, t, x, k, hc, hd)

# A caller chooses numeric trace positions for each backwards scalar observation.
# These are erased proof-layout data, not runtime allocation or source snapshots.
type Observation is Data:
  Observation{word: Nat, encoder: Nat, decoder: Nat, lane: Nat}

def Layout(n: Nat, obs: List<&2, Observation>, +i: U32, +len: U32, +words: Nat, +cells: Nat) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      match obs:
        case Nil{}:
          Empty
        case Con{Observation{x, ep, dp, k}, rest}:
          P.lt(x, words) & (P.lt(U32.to_nat((i >> 3n : U32)), cells) & (EncodeLocation(len, ep, i, x) & (DecodeLocation(len, dp, i, x, k) & Layout(p, rest, (i - 1 : U32), len, words, cells))))

def roundtrip_list_go(~enc: F32 -> U32, ~dec: U32 -> F32, ~rt: @v:F32 -> {dec(enc(v)) == v : F32}, +n: Nat, +obs: List<&2, Observation>, +i: U32, +len: U32, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>, +out: List<&2, A.Cell>, +acc: List<&2, F32>, layout: Layout(n, obs, i, len, P.len(U32, 0, w), P.len(A.Cell, A.zero(), out))) -> {source_list_go(n, src, source_peek(src, i), i, acc) == list_go(n, decode(~dec, len, encode(~enc, len, src, w), out), peek(decode(~dec, len, encode(~enc, len, src, w), out), i), i, acc) : List<&2, F32>}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      match obs:
        case Nil{}:
          P.efq({source_list_go(1n+p, src, source_peek(src, i), i, acc) == list_go(1n+p, decode(~dec, len, encode(~enc, len, src, w), out), peek(decode(~dec, len, encode(~enc, len, src, w), out), i), i, acc) : List<&2, F32>}, layout)
        case Con{Observation{+x, +ep, +dp, +k}, +rest}:
          (hw, (hc, (he, (hd, tail_layout)))) = layout
          %Equal.sym(F32, source_peek(src, i), peek(decode(~dec, len, encode(~enc, len, src, w), out), i), roundtrip_at(~enc, ~dec, ~rt, len, src, w, out, i, x, ep, dp, k, hw, hc, he, hd)) : {source_list_go(p, src, source_peek(src, (i - 1 : U32)), (i - 1 : U32), Con{_, acc}) == list_go(1n+p, decode(~dec, len, encode(~enc, len, src, w), out), peek(decode(~dec, len, encode(~enc, len, src, w), out), i), i, acc) : List<&2, F32>}
          roundtrip_list_go(~enc, ~dec, ~rt, p, rest, (i - 1 : U32), len, src, w, out, Con{peek(decode(~dec, len, encode(~enc, len, src, w), out), i), acc}, tail_layout)

def roundtrip_list(~enc: F32 -> U32, ~dec: U32 -> F32, ~rt: @v:F32 -> {dec(enc(v)) == v : F32}, +len: U32, +src: Arr.Tree<A.Cell>, +w: List<&2, U32>, +out: List<&2, A.Cell>, +obs: List<&2, Observation>, layout: Layout(U32.to_nat(len), obs, (len - 1 : U32), len, P.len(U32, 0, w), P.len(A.Cell, A.zero(), out))) -> {source_list(len, src) == to_list(len, decode(~dec, len, encode(~enc, len, src, w), out)) : List<&2, F32>}:
  roundtrip_list_go(~enc, ~dec, ~rt, U32.to_nat(len), obs, (len - 1 : U32), len, src, w, out, Nil{}, layout)

def cell_length(~enc: F32 -> U32, +c: A.Cell, +w: List<&2, U32>, +j: U32) -> {P.len(U32, 0, cell(~enc, c, w, j)) == P.len(U32, 0, w) : Nat}:
  %Equal.sym(List<&2, U32>, cell(~enc, c, w, j), apply(~enc, cell_trace(0, j), Arr.Leaf{c}, w), cell_apply(~enc, Arr.Leaf{c}, 0, w, j)) : {P.len(U32, 0, _) == P.len(U32, 0, w) : Nat}
  apply_length(~enc, cell_trace(0, j), Arr.Leaf{c}, w)

def from_go_length(~dec: U32 -> F32, +n: Nat, +w: List<&2, U32>, +c: A.Cell, +out: List<&2, A.Cell>, +i: U32) -> {P.len(A.Cell, A.zero(), from_go(~dec, n, w, c, out, i)) == P.len(A.Cell, A.zero(), out) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      +j = (i + 1 : U32)
      Equal.trans(Nat, P.len(A.Cell, A.zero(), from_go(~dec, 1n+p, w, c, out, i)), P.len(A.Cell, A.zero(), P.upd(A.Cell, A.zero(), out, U32.to_nat(i), c)), P.len(A.Cell, A.zero(), out),
        from_go_length(~dec, p, w, read_cell(~dec, w, (j << 3n : U32)), P.upd(A.Cell, A.zero(), out, U32.to_nat(i), c), j),
        P.len_upd(A.Cell, A.zero(), out, U32.to_nat(i), c))
