import Base
import ./f32array.bend as A
import ./LAWS.bend as Laws
import ./codec-model.bend as C
import ./codec-bridge.bend as B
import ../lemmas/array.bend as Arr
import ../lemmas/perfect.bend as P
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def values(~enc: F32 -> U32, ~dec: U32 -> F32, xs: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{v, t}:
      Con{dec(enc(v)), values(~enc, ~dec, t)}

def restore(~enc: F32 -> U32, ~dec: U32 -> F32, ~rt: @v:F32 -> {dec(enc(v)) == v : F32}, +xs: List<&2, F32>) -> {values(~enc, ~dec, xs) == xs : List<&2, F32>}:
  match xs:
    case Nil{}:
      {==}
    case Con{+v, +t}:
      %Equal.sym(F32, dec(enc(v)), v, rt(v)) : {Con{_, values(~enc, ~dec, t)} == Con{v, t} : List<&2, F32>}
      Equal.cong(List<&2, F32>, List<&2, F32>, l => Con{v, l}, values(~enc, ~dec, t), t, restore(~enc, ~dec, ~rt, t))

# Small allocations wrap unused decoder reads; prove their visible lanes directly.
def leaf_roundtrip(~enc: F32 -> U32, ~dec: U32 -> F32, ~rt: @v:F32 -> {dec(enc(v)) == v : F32}, c: A.Cell, +n: Nat, h: P.lt(n, 8n)) -> {Laws.lists(C.from_bytes(~dec, A.to_bytes.with(~enc, A.F32Array{U32.from_nat(n), ALeaf{c}}))) == Some{A.to_list(A.F32Array{U32.from_nat(n), ALeaf{c}})} : Maybe<&2, List<&2, F32>>}:
  match c:
    case A.Cell{+v0, +v1, +v2, +v3, +v4, +v5, +v6, +v7}:
      match n:
        case 0n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, []), [], restore(~enc, ~dec, ~rt, []))
        case 1n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, [v0]), [v0], restore(~enc, ~dec, ~rt, [v0]))
        case 2n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, [v0, v1]), [v0, v1], restore(~enc, ~dec, ~rt, [v0, v1]))
        case 3n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, [v0, v1, v2]), [v0, v1, v2], restore(~enc, ~dec, ~rt, [v0, v1, v2]))
        case 4n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, [v0, v1, v2, v3]), [v0, v1, v2, v3], restore(~enc, ~dec, ~rt, [v0, v1, v2, v3]))
        case 5n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, [v0, v1, v2, v3, v4]), [v0, v1, v2, v3, v4], restore(~enc, ~dec, ~rt, [v0, v1, v2, v3, v4]))
        case 6n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, [v0, v1, v2, v3, v4, v5]), [v0, v1, v2, v3, v4, v5], restore(~enc, ~dec, ~rt, [v0, v1, v2, v3, v4, v5]))
        case 7n:
          Equal.cong(List<&2, F32>, Maybe<&2, List<&2, F32>>, l => Some{l}, values(~enc, ~dec, [v0, v1, v2, v3, v4, v5, v6]), [v0, v1, v2, v3, v4, v5, v6], restore(~enc, ~dec, ~rt, [v0, v1, v2, v3, v4, v5, v6]))
        case 8n+p:
          P.efq({Laws.lists(C.from_bytes(~dec, A.to_bytes.with(~enc, A.F32Array{U32.from_nat(8n+p), ALeaf{A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}}}))) == Some{A.to_list(A.F32Array{U32.from_nat(8n+p), ALeaf{A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}}})} : Maybe<&2, List<&2, F32>>}, P.lt_zero(p, h))

def encode(~enc: F32 -> U32, +n: Nat, +src: Arr.Tree<A.Cell>, h: P.lt(n, 8n)) -> {A.to_bytes.with(~enc, A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)}) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}:
  match n:
    case 0n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(0n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(0n), _, Bytes.alloc((U32.from_nat(0n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(0n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 1n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(1n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(1n), _, Bytes.alloc((U32.from_nat(1n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(1n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 2n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(2n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(2n), _, Bytes.alloc((U32.from_nat(2n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(2n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 3n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(3n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(3n), _, Bytes.alloc((U32.from_nat(3n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(3n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 4n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(4n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(4n), _, Bytes.alloc((U32.from_nat(4n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(4n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 5n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(5n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(5n), _, Bytes.alloc((U32.from_nat(5n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(5n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 6n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(6n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(6n), _, Bytes.alloc((U32.from_nat(6n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(6n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 7n:
      %Arr.tree_get(A.Cell, src, 0) : {A.to.fin((U32.from_nat(7n) << 2n : U32), A.to.go(~enc, 0n, U32.from_nat(7n), _, Bytes.alloc((U32.from_nat(7n) << 2n : U32)), 0)) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(7n), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}
      {==}
    case 8n+p:
      P.efq({A.to_bytes.with(~enc, A.F32Array{U32.from_nat(8n+p), Arr.reify(A.Cell, src)}) == A.to_bytes.with(~enc, A.F32Array{U32.from_nat(8n+p), ALeaf{Arr.read(A.Cell, src, 0)}}) : Bytes.Bytes}, P.lt_zero(p, h))

def source(+n: Nat, +src: Arr.Tree<A.Cell>, h: P.lt(n, 8n)) -> {C.source_list(U32.from_nat(n), src) == A.to_list(A.F32Array{U32.from_nat(n), ALeaf{Arr.read(A.Cell, src, 0)}}) : List<&2, F32>}:
  match n:
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
      P.efq({C.source_list(U32.from_nat(8n+p), src) == A.to_list(A.F32Array{U32.from_nat(8n+p), ALeaf{Arr.read(A.Cell, src, 0)}}) : List<&2, F32>}, P.lt_zero(p, h))

def source_list(+n: Nat, +src: Arr.Tree<A.Cell>, h: P.lt(n, 8n)) -> {A.to_list(A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)}) == A.to_list(A.F32Array{U32.from_nat(n), ALeaf{Arr.read(A.Cell, src, 0)}}) : List<&2, F32>}:
  Equal.trans(List<&2, F32>, A.to_list(A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)}), C.source_list(U32.from_nat(n), src), A.to_list(A.F32Array{U32.from_nat(n), ALeaf{Arr.read(A.Cell, src, 0)}}), B.source_list_model(U32.from_nat(n), src), source(n, src, h))

def roundtrip(~enc: F32 -> U32, ~dec: U32 -> F32, ~rt: @v:F32 -> {dec(enc(v)) == v : F32}, +n: Nat, +src: Arr.Tree<A.Cell>, +h: P.lt(n, 8n)) -> {Laws.lists(C.from_bytes(~dec, A.to_bytes.with(~enc, A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)}))) == Some{A.to_list(A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}:
  %Equal.sym(Bytes.Bytes, A.to_bytes.with(~enc, A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)}), A.to_bytes.with(~enc, A.F32Array{U32.from_nat(n), ALeaf{Arr.read(A.Cell, src, 0)}}), encode(~enc, n, src, h)) : {Laws.lists(C.from_bytes(~dec, _)) == Some{A.to_list(A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)})} : Maybe<&2, List<&2, F32>>}
  %Equal.sym(List<&2, F32>, A.to_list(A.F32Array{U32.from_nat(n), Arr.reify(A.Cell, src)}), A.to_list(A.F32Array{U32.from_nat(n), ALeaf{Arr.read(A.Cell, src, 0)}}), source_list(n, src, h)) : {Laws.lists(C.from_bytes(~dec, A.to_bytes.with(~enc, A.F32Array{U32.from_nat(n), ALeaf{Arr.read(A.Cell, src, 0)}}))) == Some{_} : Maybe<&2, List<&2, F32>>}
  leaf_roundtrip(~enc, ~dec, ~rt, Arr.read(A.Cell, src, 0), n, h)
