import Base
import ./f32array.bend as A
import ./LAWS.bend as Laws
import ./codec-model.bend as C
import ./codec-bridge.bend as B
import ./allocation-proof.bend as Alloc
import ./trace-layout.bend as Trace
import ./trim-proof.bend as Trim
import ./small-proof.bend as Small
import ./layout-proof.bend as G
import ../lemmas/array.bend as Arr
import ../lemmas/perfect.bend as P
import ../lemmas/lemmas.bend as L
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as N

def top_bit(n: Nat) -> Word(1n+n):
  match n:
    case 0n:
      WCon{True{}, WNil{}}
    case 1n+p:
      WCon{False{}, top_bit(p)}

def top_bit_nat(+n: Nat) -> {Word.to_nat(1n+n, top_bit(n)) == L.pow2(n) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      Equal.cong(Nat, Nat, Nat.double, Word.to_nat(1n+p, top_bit(p)), L.pow2(p), top_bit_nat(p))

# Compare the finite words before natural powers: https://github.com/bendlang/bend/issues/1071.
def limit_word() -> {U32.shln(1, 30n) == U32{Word.shr.pad(31n, top_bit(30n))} : U32}:
  {==}

def limit_nat() -> {U32.to_nat(U32.shln(1, 30n)) == L.pow2(30n) : Nat}:
  %Equal.sym(U32, U32.shln(1, 30n), U32{Word.shr.pad(31n, top_bit(30n))}, limit_word()) : {U32.to_nat(_) == L.pow2(30n) : Nat}
  Equal.trans(Nat, U32.to_nat(U32{Word.shr.pad(31n, top_bit(30n))}), Word.to_nat(32n, Word.shr.pad(31n, top_bit(30n))), L.pow2(30n), Equal.sym(Nat, Word.to_nat(32n, Word.shr.pad(31n, top_bit(30n))), U32.to_nat(U32{Word.shr.pad(31n, top_bit(30n))}), L.u32_to_nat_word(Word.shr.pad(31n, top_bit(30n)))), Equal.trans(Nat, Word.to_nat(32n, Word.shr.pad(31n, top_bit(30n))), Word.to_nat(31n, top_bit(30n)), L.pow2(30n), G.pad_nat(31n, top_bit(30n)), top_bit_nat(30n)))

def u32_lt(+a: U32, +b: U32, h: {U32.is_lt(a, b) == True{} : Bool}) -> P.lt(U32.to_nat(a), U32.to_nat(b)):
  G.proof_lt(U32.to_nat(a), U32.to_nat(b), Equal.trans(Bool, Nat.is_lt(U32.to_nat(a), U32.to_nat(b)), U32.is_lt(a, b), True{}, Equal.sym(Bool, U32.is_lt(a, b), Nat.is_lt(U32.to_nat(a), U32.to_nat(b)), L.u32_is_lt_nat(a, b)), h))

def length_bound(+len: U32, h: {U32.is_lt(len, U32.shln(1, 30n)) == True{} : Bool}) -> P.lt(U32.to_nat(len), L.pow2(30n)):
  G.upper_rw(U32.to_nat(len), U32.to_nat(U32.shln(1, 30n)), L.pow2(30n), limit_nat(), u32_lt(len, U32.shln(1, 30n), h))

def decoded_capacity(+len: U32, +w: List<&2, U32>, +out: List<&2, A.Cell>, h: P.le(Alloc.cell_capacity(len), P.len(A.Cell, A.zero(), out))) -> P.le(Alloc.cell_capacity(len), P.len(A.Cell, A.zero(), C.decode(len, w, out))):
  %Equal.sym(Nat, P.len(A.Cell, A.zero(), C.decode(len, w, out)), P.len(A.Cell, A.zero(), out), C.from_go_length(U32.to_nat(A.cells(len)), w, C.read_cell(w, 0), out, 0)) : P.le(Alloc.cell_capacity(len), _)
  h

def large_roundtrip(+len: U32, +src: Arr.Tree<A.Cell>, +h: P.lt(U32.to_nat(len), L.pow2(30n)), +h8: P.le(8n, U32.to_nat(len))) -> {Laws.lists(A.from_bytes.le(A.to_bytes.le(A.F32Array{len, Arr.reify(A.Cell, src)}))) == Some{A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}:
  +dw = Alloc.word_depth(len)
  +dc = Alloc.cell_depth(len)
  +w = Alloc.replicate(U32, 0, Alloc.word_capacity(len))
  +out = Alloc.replicate(A.Cell, A.zero(), Alloc.cell_capacity(len))
  +encoded = C.encode(len, src, w)
  +decoded = C.decode(len, encoded, out)
  +hdw = Alloc.word_depth_bound(len, h)
  +hdc = Alloc.cell_depth_bound(len, h)
  +hlw : P.le(Alloc.word_capacity(len), P.len(U32, 0, w)) = (
    %Equal.sym(Nat, P.len(U32, 0, w), Alloc.word_capacity(len), Alloc.replicate_len(U32, 0, Alloc.word_capacity(len))) : P.le(Alloc.word_capacity(len), _)
    N.le_refl(Alloc.word_capacity(len)))
  +hlc : P.le(Alloc.cell_capacity(len), P.len(A.Cell, A.zero(), out)) = (
    %Equal.sym(Nat, P.len(A.Cell, A.zero(), out), Alloc.cell_capacity(len), Alloc.replicate_len(A.Cell, A.zero(), Alloc.cell_capacity(len))) : P.le(Alloc.cell_capacity(len), _)
    N.le_refl(Alloc.cell_capacity(len)))
  +hld = decoded_capacity(len, encoded, out, hlc)
  +em = B.encode_model(len, src, dw, w, hdw, hlw, Alloc.alloc_words(len), Trace.encode_bounds(len, h))
  +dm = B.decode_model(len, dw, dc, encoded, out, h, hdw, hdc, hlc, Alloc.alloc_cells(len), Trace.decode_bounds(len, h, h8))
  +tm = Trim.trim_if_model(U32.is_ne((len .&. 7 : U32), 0), len, dc, decoded, hdc, hld, Trace.trim_index(len, h), Trace.list_bounds(len, h), Trace.list_bounds(len, h), Trace.logical_bounds(len))
  +lm = B.to_list_model(len, dc, decoded, hdc, Trace.list_bounds(len, h))
  +rt = Trace.roundtrip(len, src, w, out, h, N.le_trans(U32.to_nat(len), Alloc.word_capacity(len), P.len(U32, 0, w), Alloc.words_cover(len, h), hlw), N.le_trans(U32.to_nat(A.cells(len)), Alloc.cell_capacity(len), P.len(A.Cell, A.zero(), out), Alloc.cells_cover(len, h), hlc))
  %Equal.sym(Bytes.Bytes, A.to_bytes.le(A.F32Array{len, Arr.reify(A.Cell, src)}), Bytes.Bytes{(len << 2n : U32), P.build(U32, 0, dw, encoded)}, em) : {Laws.lists(A.from_bytes.le(_)) == Some{A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}
  %Equal.sym(Maybe<&1, A.F32Array>, A.from_bytes.le(Bytes.Bytes{(len << 2n : U32), P.build(U32, 0, dw, encoded)}), Some{A.F32Array{len, A.trim(P.build(A.Cell, A.zero(), dc, decoded), len)}}, dm) : {Laws.lists(_) == Some{A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}
  %Equal.sym(List<&2, F32>, A.to_list(A.F32Array{len, A.trim(P.build(A.Cell, A.zero(), dc, decoded), len)}), A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), dc, decoded)}), tm) : {Some{_} == Some{A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}
  %Equal.sym(List<&2, F32>, A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), dc, decoded)}), C.to_list(len, decoded), lm) : {Some{_} == Some{A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}
  %rt : {Some{_} == Some{A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}
  Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, xs => Some{xs}, C.source_list(len, src), A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)}), Equal.sym(List<&2, F32>, A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)}), C.source_list(len, src), B.source_list_model(len, src)))

def roundtrip_if(small: Bool, +len: U32, +src: Arr.Tree<A.Cell>, +h: P.lt(U32.to_nat(len), L.pow2(30n)), e: {small == Nat.is_lt(U32.to_nat(len), 8n) : Bool}) -> {Laws.lists(A.from_bytes.le(A.to_bytes.le(A.F32Array{len, Arr.reify(A.Cell, src)}))) == Some{A.to_list(A.F32Array{len, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}:
  match small:
    case True{}:
      %L.u32_from_to_nat(len) : {Laws.lists(A.from_bytes.le(A.to_bytes.le(A.F32Array{_, Arr.reify(A.Cell, src)}))) == Some{A.to_list(A.F32Array{_, Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}
      Small.roundtrip(U32.to_nat(len), src, Equal.sym(Bool, True{}, Nat.is_lt(U32.to_nat(len), 8n), e))
    case False{}:
      large_roundtrip(len, src, h, N.le_of_not_lt(U32.to_nat(len), 8n, Equal.sym(Bool, False{}, Nat.is_lt(U32.to_nat(len), 8n), e)))

def snapshot_roundtrip(+len: U32, -a: Array<A.Cell>, +h: P.lt(U32.to_nat(len), L.pow2(30n)), snap: Arr.Snapshot(A.Cell, a)) -> {Laws.lists(A.from_bytes.le(A.to_bytes.le(A.F32Array{len, a}))) == Some{A.to_list(A.F32Array{len, a})} : Maybe<&2, List<&2, F32>>}:
  match snap:
    case Tuple{+src, Tuple{eq, u}}:
      %eq : {Laws.lists(A.from_bytes.le(A.to_bytes.le(A.F32Array{len, _}))) == Some{A.to_list(A.F32Array{len, _})} : Maybe<&2, List<&2, F32>>}
      roundtrip_if(Nat.is_lt(U32.to_nat(len), 8n), len, src, h, {==})

def roundtrip(a: A.F32Array, h: {U32.is_lt(Laws.len(a), U32.shln(1, 30n)) == True{} : Bool}) -> {Laws.lists(A.from_bytes.le(A.to_bytes.le(a))) == Some{Laws.list(a)} : Maybe<&2, List<&2, F32>>}:
  match a:
    case A.F32Array{+len, buf}:
      snapshot_roundtrip(len, buf, length_bound(len, h), Arr.snapshot(A.Cell, buf))
