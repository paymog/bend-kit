import Base
import ./f32array.bend as A
import ./codec-model.bend as C
import ./codec-bridge.bend as B
import ./layout-proof.bend as Layout
import ../lemmas/perfect.bend as P
import ../lemmas/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N

def LogicalBounds(n: Nat, +i: U32, +len: U32) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      P.lt(U32.to_nat(i), U32.to_nat(len)) & LogicalBounds(p, (i - 1 : U32), len)

def TrimIndex(part: Bool, +len: U32, +d: Nat) -> Type:
  match part:
    case False{}:
      Unit
    case True{}:
      P.lt(U32.to_nat((len >> 3n : U32)), Nat.pow(2n, d))

def mask_nat(c: A.Cell, +k: Nat, +lane: Nat, hk: P.lt(k, 8n), hl: P.lt(lane, k)) -> {A.lane(A.mask(c, U32.from_nat(k)), U32.from_nat(lane)) == A.lane(c, U32.from_nat(lane)) : F32}:
  match c:
    case A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}:
      match k:
        case 0n:
          P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 0), U32.from_nat(lane)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(lane)) : F32}, P.lt_zero(lane, hl))
        case 1n:
          match lane:
            case 0n:
              {==}
            case 1n+p:
              P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 1), U32.from_nat(1n+p)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(1n+p)) : F32}, P.lt_zero(p, hl))
        case 2n:
          match lane:
            case 0n:
              {==}
            case 1n:
              {==}
            case 2n+p:
              P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 2), U32.from_nat(2n+p)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(2n+p)) : F32}, P.lt_zero(p, hl))
        case 3n:
          match lane:
            case 0n:
              {==}
            case 1n:
              {==}
            case 2n:
              {==}
            case 3n+p:
              P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 3), U32.from_nat(3n+p)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(3n+p)) : F32}, P.lt_zero(p, hl))
        case 4n:
          match lane:
            case 0n:
              {==}
            case 1n:
              {==}
            case 2n:
              {==}
            case 3n:
              {==}
            case 4n+p:
              P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 4), U32.from_nat(4n+p)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(4n+p)) : F32}, P.lt_zero(p, hl))
        case 5n:
          match lane:
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
            case 5n+p:
              P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 5), U32.from_nat(5n+p)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(5n+p)) : F32}, P.lt_zero(p, hl))
        case 6n:
          match lane:
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
            case 6n+p:
              P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 6), U32.from_nat(6n+p)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(6n+p)) : F32}, P.lt_zero(p, hl))
        case 7n:
          match lane:
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
            case 7n+p:
              P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, 7), U32.from_nat(7n+p)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(7n+p)) : F32}, P.lt_zero(p, hl))
        case 8n+p:
          P.efq({A.lane(A.mask(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(8n+p)), U32.from_nat(lane)) == A.lane(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(lane)) : F32}, P.lt_zero(p, hk))

def mask_lane(c: A.Cell, +k: U32, +lane: U32, hk: P.lt(U32.to_nat(k), 8n), hl: P.lt(U32.to_nat(lane), U32.to_nat(k))) -> {A.lane(A.mask(c, k), lane) == A.lane(c, lane) : F32}:
  %L.u32_from_to_nat(k) : {A.lane(A.mask(c, _), lane) == A.lane(c, lane) : F32}
  %L.u32_from_to_nat(lane) : {A.lane(A.mask(c, U32.from_nat(U32.to_nat(k))), _) == A.lane(c, _) : F32}
  mask_nat(c, U32.to_nat(k), U32.to_nat(lane), hk, hl)

def nat_eq(+a: Nat, +b: Nat, h: {Nat.is_eq(a, b) == True{} : Bool}) -> {a == b : Nat}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      P.efq({0n == 1n+q : Nat}, P.ft(h))
    case 1n+p 0n:
      P.efq({1n+p == 0n : Nat}, P.ft(h))
    case 1n++p 1n++q:
      Equal.cong(Nat, Nat, n => 1n+n, p, q, nat_eq(p, q, h))

def same_lane_bound(+i: U32, +len: U32, hi: P.lt(U32.to_nat(i), U32.to_nat(len)), +e: {U32.to_nat((i >> 3n : U32)) == U32.to_nat((len >> 3n : U32)) : Nat}) -> P.lt(U32.to_nat((i .&. 7 : U32)), U32.to_nat((len .&. 7 : U32))):
  %Equal.sym(Bool, Nat.is_lt(U32.to_nat((i .&. 7 : U32)), U32.to_nat((len .&. 7 : U32))), Nat.is_lt(Nat.add(Nat.mul(8n, U32.to_nat((i >> 3n : U32))), U32.to_nat((i .&. 7 : U32))), Nat.add(Nat.mul(8n, U32.to_nat((i >> 3n : U32))), U32.to_nat((len .&. 7 : U32)))), N.add_lt_add_iff_left(Nat.mul(8n, U32.to_nat((i >> 3n : U32))), U32.to_nat((i .&. 7 : U32)), U32.to_nat((len .&. 7 : U32)))) : {_ == True{} : Bool}
  %Layout.split3(i) : {Nat.is_lt(_, Nat.add(Nat.mul(8n, U32.to_nat((i >> 3n : U32))), U32.to_nat((len .&. 7 : U32)))) == True{} : Bool}
  %Equal.sym(Nat, U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32)), e) : {Nat.is_lt(U32.to_nat(i), Nat.add(Nat.mul(8n, _), U32.to_nat((len .&. 7 : U32)))) == True{} : Bool}
  %Layout.split3(len) : {Nat.is_lt(U32.to_nat(i), _) == True{} : Bool}
  hi

def masked(+len: U32, +out: List<&2, A.Cell>) -> List<&2, A.Cell>:
  P.upd(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32)), A.mask(P.nth(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32))), (len .&. 7 : U32)))

def masked_peek_if(same: Bool, +out: List<&2, A.Cell>, +len: U32, +i: U32, +hs: P.lt(U32.to_nat((len >> 3n : U32)), P.len(A.Cell, A.zero(), out)), +hi: P.lt(U32.to_nat(i), U32.to_nat(len)), e: {same == Nat.is_eq(U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32))) : Bool}) -> {C.peek(masked(len, out), i) == C.peek(out, i) : F32}:
  match same:
    case False{}:
      Equal.sym(F32, C.peek(out, i), C.peek(masked(len, out), i), Equal.cong(A.Cell, F32, c => A.lane(c, (i .&. 7 : U32)), P.nth(A.Cell, A.zero(), out, U32.to_nat((i >> 3n : U32))), P.nth(A.Cell, A.zero(), masked(len, out), U32.to_nat((i >> 3n : U32))), C.nth_upd_ne(A.Cell, A.zero(), out, U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32)), A.mask(P.nth(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32))), (len .&. 7 : U32)), Equal.sym(Bool, False{}, Nat.is_eq(U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32))), e))))
    case True{}:
      +eq = nat_eq(U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32)), Equal.sym(Bool, True{}, Nat.is_eq(U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32))), e))
      %Equal.sym(Nat, U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32)), eq) : {A.lane(P.nth(A.Cell, A.zero(), masked(len, out), _), (i .&. 7 : U32)) == A.lane(P.nth(A.Cell, A.zero(), out, _), (i .&. 7 : U32)) : F32}
      %P.nth_upd_same(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32)), A.mask(P.nth(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32))), (len .&. 7 : U32)), hs) : {A.lane(_, (i .&. 7 : U32)) == A.lane(P.nth(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32))), (i .&. 7 : U32)) : F32}
      mask_lane(P.nth(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32))), (len .&. 7 : U32), (i .&. 7 : U32), Layout.bound3(len), same_lane_bound(i, len, hi, eq))

def masked_peek(+out: List<&2, A.Cell>, +len: U32, +i: U32, +hs: P.lt(U32.to_nat((len >> 3n : U32)), P.len(A.Cell, A.zero(), out)), +hi: P.lt(U32.to_nat(i), U32.to_nat(len))) -> {C.peek(masked(len, out), i) == C.peek(out, i) : F32}:
  masked_peek_if(Nat.is_eq(U32.to_nat((i >> 3n : U32)), U32.to_nat((len >> 3n : U32))), out, len, i, hs, hi, {==})

def masked_list_go(+n: Nat, +out: List<&2, A.Cell>, +len: U32, +i: U32, +acc: List<&2, F32>, +hs: P.lt(U32.to_nat((len >> 3n : U32)), P.len(A.Cell, A.zero(), out)), hb: LogicalBounds(n, i, len)) -> {C.list_go(n, masked(len, out), C.peek(masked(len, out), i), i, acc) == C.list_go(n, out, C.peek(out, i), i, acc) : List<&2, F32>}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      match hb:
        case Tuple{hi, rest}:
          %masked_peek(out, len, i, hs, hi) : {C.list_go(p, masked(len, out), C.peek(masked(len, out), (i - 1 : U32)), (i - 1 : U32), Con{C.peek(masked(len, out), i), acc}) == C.list_go(p, out, C.peek(out, (i - 1 : U32)), (i - 1 : U32), Con{_, acc}) : List<&2, F32>}
          masked_list_go(p, out, len, (i - 1 : U32), Con{C.peek(masked(len, out), i), acc}, hs, rest)

def masked_list(+out: List<&2, A.Cell>, +len: U32, +hs: P.lt(U32.to_nat((len >> 3n : U32)), P.len(A.Cell, A.zero(), out)), hb: LogicalBounds(U32.to_nat(len), (len - 1 : U32), len)) -> {C.to_list(len, masked(len, out)) == C.to_list(len, out) : List<&2, F32>}:
  masked_list_go(U32.to_nat(len), out, len, (len - 1 : U32), Nil{}, hs, hb)

def trim_if_model(part: Bool, +len: U32, +d: Nat, +out: List<&2, A.Cell>, +hd: P.lt(d, 32n), +hl: P.le(Nat.pow(2n, d), P.len(A.Cell, A.zero(), out)), ht: TrimIndex(part, len, d), hb1: B.ListBounds(d, U32.to_nat(len), (len - 1 : U32)), hb2: B.ListBounds(d, U32.to_nat(len), (len - 1 : U32)), logical: LogicalBounds(U32.to_nat(len), (len - 1 : U32), len)) -> {A.to_list(A.F32Array{len, A.trim.if(part, P.build(A.Cell, A.zero(), d, out), len)}) == A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, out)}) : List<&2, F32>}:
  match part:
    case False{}:
      {==}
    case True{}:
      +ht : P.lt(U32.to_nat((len >> 3n : U32)), Nat.pow(2n, d)) = ht
      %P.get_r(A.Cell, A.zero(), d, out, (len >> 3n : U32), hd, ht) : {A.to_list(A.F32Array{len, A.trim.of((len >> 3n : U32), (len .&. 7 : U32), _)}) == A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, out)}) : List<&2, F32>}
      %P.set_r(A.Cell, A.zero(), d, out, (len >> 3n : U32), A.mask(P.nth(A.Cell, A.zero(), out, U32.to_nat((len >> 3n : U32))), (len .&. 7 : U32)), hd, ht, hl) : {A.to_list(A.F32Array{len, _}) == A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, out)}) : List<&2, F32>}
      Equal.trans(List<&2, F32>, A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, masked(len, out))}), C.to_list(len, masked(len, out)), A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, out)}), B.to_list_model(len, d, masked(len, out), hd, hb1), Equal.trans(List<&2, F32>, C.to_list(len, masked(len, out)), C.to_list(len, out), A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, out)}), masked_list(out, len, N.lt_of_lt_of_le(U32.to_nat((len >> 3n : U32)), Nat.pow(2n, d), P.len(A.Cell, A.zero(), out), ht, hl), logical), Equal.sym(List<&2, F32>, A.to_list(A.F32Array{len, P.build(A.Cell, A.zero(), d, out)}), C.to_list(len, out), B.to_list_model(len, d, out, hd, hb2))))
