# Numeric layout witnesses for codec-model; no facts about stored values.
import Base
import ./codec-model.bend as C
import ./f32array.bend as A
import ./layout-proof.bend as G
import ./allocation-proof.bend as Alloc
import ./codec-bridge.bend as Bridge
import ./trim-proof.bend as Trim
import ../lemmas/lemmas.bend as L
import ../lemmas/perfect.bend as P
import ../lemmas/array.bend as Arr
import bend-mathlib@0.8.0.0/nat.bend as N

# Explicit coordinate facts let the semantic proof remain independent of bounds.
def Sequence(xs: List<&2, C.Write>, +b: Nat) -> Type:
  match xs:
    case Nil{}:
      Unit
    case Con{C.Write{at, ci, lane}, rest}:
      {at == b : Nat} & ({at == Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)) : Nat} & (P.lt(U32.to_nat(lane), 8n) & Sequence(rest, 1n+b)))

def size(xs: List<&2, C.Write>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{x, rest}:
      1n+size(rest)

def ne_of_lt(+a: Nat, +b: Nat, +h: P.lt(a, b)) -> {Nat.is_eq(a, b) == False{} : Bool}:
  match a:
    case 0n:
      match b:
        case 0n:
          P.efq({True{} == False{} : Bool}, P.ft(h))
        case 1n+q:
          {==}
    case 1n++p:
      match b:
        case 0n:
          {==}
        case 1n++q:
          ne_of_lt(p, q, h)

def avoid_sequence(+xs: List<&2, C.Write>, +b: Nat, +x: Nat, +hx: P.lt(x, b), seq: Sequence(xs, b)) -> C.Avoid(xs, x):
  match xs:
    case Nil{}:
      Unit{}
    case Con{C.Write{+at, +ci, +lane}, +rest}:
      (+ea, (ec, (hl, tail))) = seq
      ((%Equal.sym(Nat, at, b, ea) : {Nat.is_eq(x, _) == False{} : Bool}
        ne_of_lt(x, b, hx)),
       avoid_sequence(rest, 1n+b, x, N.lt_trans(x, b, 1n+b, hx, N.lt_succ_self(b)), tail))

def source_coordinate(+ci: U32, +lane: U32, +t: U32,
  +e: {U32.to_nat(t) == Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)) : Nat},
  +hl: P.lt(U32.to_nat(lane), 8n)) -> {ci == (t >> 3n : U32) : U32} & {lane == (t .&. 7 : U32) : U32}:
  +eq = Equal.trans(Nat, U32.to_nat(ci), Nat.div(U32.to_nat(t), 8n), U32.to_nat((t >> 3n : U32)),
    Equal.sym(Nat, Nat.div(U32.to_nat(t), 8n), U32.to_nat(ci), G.quotient(U32.to_nat(t), U32.to_nat(ci), U32.to_nat(lane), 7n, e, hl)),
    Equal.sym(Nat, U32.to_nat((t >> 3n : U32)), Nat.div(U32.to_nat(t), 8n), G.shr3_nat(t)))
  +es = Equal.trans(Nat,
    Nat.add(Nat.mul(8n, U32.to_nat((t >> 3n : U32))), U32.to_nat(lane)),
    Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)),
    Nat.add(Nat.mul(8n, U32.to_nat((t >> 3n : U32))), U32.to_nat((t .&. 7 : U32))),
    Equal.cong(Nat, Nat, q => Nat.add(Nat.mul(8n, q), U32.to_nat(lane)), U32.to_nat((t >> 3n : U32)), U32.to_nat(ci), Equal.sym(Nat, U32.to_nat(ci), U32.to_nat((t >> 3n : U32)), eq)),
    Equal.trans(Nat, Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)), U32.to_nat(t), Nat.add(Nat.mul(8n, U32.to_nat((t >> 3n : U32))), U32.to_nat((t .&. 7 : U32))), Equal.sym(Nat, U32.to_nat(t), Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)), e), G.split3(t)))
  (L.u32_to_nat_inj(ci, (t >> 3n : U32), eq), L.u32_to_nat_inj(lane, (t .&. 7 : U32), N.add_left_cancel(Nat.mul(8n, U32.to_nat((t >> 3n : U32))), U32.to_nat(lane), U32.to_nat((t .&. 7 : U32)), es)))

def sequence_location(+xs: List<&2, C.Write>, +p: Nat, +b: Nat, +t: U32,
  +hp: P.lt(p, size(xs)), +ex: {Nat.add(p, b) == U32.to_nat(t) : Nat}, seq: Sequence(xs, b)) -> C.Location(xs, p, t, U32.to_nat(t)):
  match xs:
    case Nil{}:
      P.efq(C.Location(Nil{}, p, t, U32.to_nat(t)), P.lt_zero(p, hp))
    case Con{C.Write{+at, +ci, +lane}, +rest}:
      (+ea, (+ec, (+hl, tail))) = seq
      match p:
        case 0n:
          +atx = Equal.trans(Nat, at, b, U32.to_nat(t), ea, ex)
          (eq, er) = source_coordinate(ci, lane, t, Equal.trans(Nat, U32.to_nat(t), at, Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)), Equal.sym(Nat, at, U32.to_nat(t), atx), ec), hl)
          (atx, (eq, (er, avoid_sequence(rest, 1n+b, U32.to_nat(t),
            (%ex : P.lt(_, 1n+b)
             N.lt_succ_self(b)), tail))))
        case 1n++q:
          sequence_location(rest, q, 1n+b, t, hp,
            Equal.trans(Nat, Nat.add(q, 1n+b), 1n+Nat.add(q, b), U32.to_nat(t), Equal.sym(Nat, 1n+Nat.add(q, b), Nat.add(q, 1n+b), P.add_succ(q, b)), ex), tail)

def sequence_append(+xs: List<&2, C.Write>, +ys: List<&2, C.Write>, +b: Nat, seq: Sequence(xs, b), next: Sequence(ys, Nat.add(size(xs), b))) -> Sequence(C.append(C.Write, xs, ys), b):
  match xs:
    case Nil{}:
      next
    case Con{C.Write{+at, +ci, +lane}, +rest}:
      (ea, (ec, (hl, tail))) = seq
      (ea, (ec, (hl, sequence_append(rest, ys, 1n+b, tail,
        (%P.add_succ(size(rest), b) : Sequence(ys, _)
         next)))))

def small_fit(+k: Nat, +hk: P.lt(k, 8n)) -> P.lt(k, L.pow2(32n)):
  N.lt_trans(k, 8n, L.pow2(32n), hk, Alloc.pow_lt(3n, 32n, {==}))

def address_offset(+i: U32, +k: Nat, +hi: P.lt(U32.to_nat(i), L.pow2(27n)), +hk: P.lt(k, 8n)) -> {U32.to_nat(((i << 3n : U32) + U32.from_nat(k) : U32)) == Nat.add(k, Nat.mul(8n, U32.to_nat(i))) : Nat}:
  +ek = L.u32_to_from_nat(k, small_fit(k, hk))
  Equal.trans(Nat, U32.to_nat(((i << 3n : U32) + U32.from_nat(k) : U32)), Nat.add(Nat.mul(8n, U32.to_nat(i)), U32.to_nat(U32.from_nat(k))), Nat.add(k, Nat.mul(8n, U32.to_nat(i))),
    G.address(i, U32.from_nat(k), hi, L.lt_rw(U32.to_nat(U32.from_nat(k)), k, 8n, ek, hk)),
    Equal.trans(Nat, Nat.add(Nat.mul(8n, U32.to_nat(i)), U32.to_nat(U32.from_nat(k))), Nat.add(Nat.mul(8n, U32.to_nat(i)), k), Nat.add(k, Nat.mul(8n, U32.to_nat(i))), Equal.cong(Nat, Nat, x => Nat.add(Nat.mul(8n, U32.to_nat(i)), x), U32.to_nat(U32.from_nat(k)), k, ek), N.add_comm(Nat.mul(8n, U32.to_nat(i)), k)))

def cell_sequence(+i: U32, +hi: P.lt(U32.to_nat(i), L.pow2(27n))) -> Sequence(C.cell_trace(i, (i << 3n : U32)), Nat.mul(8n, U32.to_nat(i))):
  (address_offset(i, 0n, hi, {==}), (G.address(i, 0, hi, {==}), ({==}, (address_offset(i, 1n, hi, {==}), (G.address(i, 1, hi, {==}), ({==}, (address_offset(i, 2n, hi, {==}), (G.address(i, 2, hi, {==}), ({==}, (address_offset(i, 3n, hi, {==}), (G.address(i, 3, hi, {==}), ({==}, (address_offset(i, 4n, hi, {==}), (G.address(i, 4, hi, {==}), ({==}, (address_offset(i, 5n, hi, {==}), (G.address(i, 5, hi, {==}), ({==}, (address_offset(i, 6n, hi, {==}), (G.address(i, 6, hi, {==}), ({==}, (address_offset(i, 7n, hi, {==}), (G.address(i, 7, hi, {==}), ({==}, Unit{}))))))))))))))))))))))))

def small30(+k: Nat, +hk: P.lt(k, 8n)) -> P.lt(k, L.pow2(30n)):
  N.lt_trans(k, 8n, L.pow2(30n), hk, Alloc.pow_lt(3n, 30n, {==}))

def offset30(+ci: U32, +lane: U32, +hi: P.lt(U32.to_nat(ci), L.pow2(27n)), +hl: P.lt(U32.to_nat(lane), 8n)) -> P.lt(Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)), L.pow2(30n)):
  %Equal.sym(Nat, L.pow2(30n), Nat.mul(8n, L.pow2(27n)), G.thrice(L.pow2(27n))) : P.lt(Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)), _)
  G.scaled_offset(U32.to_nat(ci), L.pow2(27n), 8n, U32.to_nat(lane), hi, hl)

def sum_step(+i: U32, +p: Nat, +hi: P.lt(U32.to_nat(i), L.pow2(30n))) -> {Nat.add(U32.to_nat((i + 1 : U32)), p) == Nat.add(U32.to_nat(i), 1n+p) : Nat}:
  Equal.trans(Nat, Nat.add(U32.to_nat((i + 1 : U32)), p), 1n+Nat.add(U32.to_nat(i), p), Nat.add(U32.to_nat(i), 1n+p),
    Equal.cong(Nat, Nat, x => Nat.add(x, p), U32.to_nat((i + 1 : U32)), 1n+U32.to_nat(i), Alloc.increment_nat(i, hi)),
    P.add_succ(U32.to_nat(i), p))

def next_coordinate(+ci: U32, +j: U32, +lane: U32, +ej: {U32.to_nat(j) == Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)) : Nat}, +hj: P.lt(U32.to_nat(j), L.pow2(30n)), +hl: P.lt(U32.to_nat(lane), L.pow2(30n))) -> {U32.to_nat((j + 1 : U32)) == Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat((lane + 1 : U32))) : Nat}:
  +base = Nat.mul(8n, U32.to_nat(ci))
  Equal.trans(Nat, U32.to_nat((j + 1 : U32)), 1n+U32.to_nat(j), Nat.add(base, U32.to_nat((lane + 1 : U32))), Alloc.increment_nat(j, hj),
    Equal.trans(Nat, 1n+U32.to_nat(j), 1n+Nat.add(base, U32.to_nat(lane)), Nat.add(base, U32.to_nat((lane + 1 : U32))), Equal.cong(Nat, Nat, x => 1n+x, U32.to_nat(j), Nat.add(base, U32.to_nat(lane)), ej),
      Equal.trans(Nat, 1n+Nat.add(base, U32.to_nat(lane)), Nat.add(base, 1n+U32.to_nat(lane)), Nat.add(base, U32.to_nat((lane + 1 : U32))), P.add_succ(base, U32.to_nat(lane)), Equal.cong(Nat, Nat, x => Nat.add(base, x), 1n+U32.to_nat(lane), U32.to_nat((lane + 1 : U32)), Equal.sym(Nat, U32.to_nat((lane + 1 : U32)), 1n+U32.to_nat(lane), Alloc.increment_nat(lane, hl))))))

def tail_sequence(+n: Nat, +ci: U32, +j: U32, +lane: U32,
  +hi: P.lt(U32.to_nat(ci), L.pow2(27n)),
  +hs: P.le(Nat.add(U32.to_nat(lane), n), 8n),
  +ej: {U32.to_nat(j) == Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)) : Nat}) -> Sequence(C.tail_trace(n, ci, j, lane), U32.to_nat(j)):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      +hl = N.lt_of_succ_le(U32.to_nat(lane), 8n,
        N.le_trans(1n+U32.to_nat(lane), Nat.add(U32.to_nat(lane), 1n+p), 8n,
          (%P.add_succ(U32.to_nat(lane), p) : P.le(1n+U32.to_nat(lane), _)
           N.succ_le_succ(U32.to_nat(lane), Nat.add(U32.to_nat(lane), p), N.le_add_right(U32.to_nat(lane), p))), hs))
      +hl30 = small30(U32.to_nat(lane), hl)
      +hj = L.lt_rw(U32.to_nat(j), Nat.add(Nat.mul(8n, U32.to_nat(ci)), U32.to_nat(lane)), L.pow2(30n), ej, offset30(ci, lane, hi, hl))
      ({==}, (ej, (hl,
        (%Alloc.increment_nat(j, hj) : Sequence(C.tail_trace(p, ci, (j + 1 : U32), (lane + 1 : U32)), _)
         tail_sequence(p, ci, (j + 1 : U32), (lane + 1 : U32), hi,
           (%Equal.sym(Nat, Nat.add(U32.to_nat((lane + 1 : U32)), p), Nat.add(U32.to_nat(lane), 1n+p), sum_step(lane, p, hl30)) : P.le(_, 8n)
            hs),
           next_coordinate(ci, j, lane, ej, hj, hl30))))))

def next_base(+i: U32, +hi: P.lt(U32.to_nat(i), L.pow2(30n))) -> {Nat.mul(8n, U32.to_nat((i + 1 : U32))) == 8n+Nat.mul(8n, U32.to_nat(i)) : Nat}:
  Equal.trans(Nat, Nat.mul(8n, U32.to_nat((i + 1 : U32))), Nat.mul(8n, 1n+U32.to_nat(i)), 8n+Nat.mul(8n, U32.to_nat(i)),
    Equal.cong(Nat, Nat, x => Nat.mul(8n, x), U32.to_nat((i + 1 : U32)), 1n+U32.to_nat(i), Alloc.increment_nat(i, hi)),
    Equal.trans(Nat, Nat.mul(8n, 1n+U32.to_nat(i)), Nat.add(Nat.mul(8n, U32.to_nat(i)), 8n), 8n+Nat.mul(8n, U32.to_nat(i)), N.mul_succ(8n, U32.to_nat(i)), N.add_comm(Nat.mul(8n, U32.to_nat(i)), 8n)))

def add_zero32(+x: U32) -> {(x + 0 : U32) == x : U32}:
  L.u32_to_nat_inj((x + 0 : U32), x,
    Equal.trans(Nat, U32.to_nat((x + 0 : U32)), Nat.add(U32.to_nat(x), 0n), U32.to_nat(x),
      L.u32_add_nat(x, 0, (%Equal.sym(Nat, Nat.add(U32.to_nat(x), 0n), U32.to_nat(x), N.add_zero(U32.to_nat(x))) : P.lt(_, L.pow2(32n))
                          L.u32_to_nat_lt(x))),
      N.add_zero(U32.to_nat(x))))

def shift_base(+i: U32, +hi: P.lt(U32.to_nat(i), L.pow2(27n))) -> {U32.to_nat((i << 3n : U32)) == Nat.mul(8n, U32.to_nat(i)) : Nat}:
  Equal.trans(Nat, U32.to_nat((i << 3n : U32)), U32.to_nat(((i << 3n : U32) + 0 : U32)), Nat.mul(8n, U32.to_nat(i)),
    Equal.cong(U32, Nat, U32.to_nat, (i << 3n : U32), ((i << 3n : U32) + 0 : U32), Equal.sym(U32, ((i << 3n : U32) + 0 : U32), (i << 3n : U32), add_zero32((i << 3n : U32)))),
    address_offset(i, 0n, hi, {==}))

def encode_sequence(+n: Nat, +k: U32, +i: U32,
  +hi: P.lt(Nat.add(U32.to_nat(i), n), L.pow2(27n)), +hk: P.lt(U32.to_nat(k), 8n)) -> Sequence(C.encode_trace(n, k, i), Nat.mul(8n, U32.to_nat(i))):
  +hc = N.lt_of_le_of_lt(U32.to_nat(i), Nat.add(U32.to_nat(i), n), L.pow2(27n), N.le_add_right(U32.to_nat(i), n), hi)
  match n:
    case 0n:
      %shift_base(i, hc) : Sequence(C.tail_trace(U32.to_nat(k), i, (i << 3n : U32), 0), _)
      tail_sequence(U32.to_nat(k), i, (i << 3n : U32), 0, hc, N.le_of_lt(U32.to_nat(k), 8n, hk),
        Equal.trans(Nat, U32.to_nat((i << 3n : U32)), Nat.mul(8n, U32.to_nat(i)), Nat.add(Nat.mul(8n, U32.to_nat(i)), 0n), shift_base(i, hc), Equal.sym(Nat, Nat.add(Nat.mul(8n, U32.to_nat(i)), 0n), Nat.mul(8n, U32.to_nat(i)), N.add_zero(Nat.mul(8n, U32.to_nat(i))))))
    case 1n++p:
      +hc30 = N.lt_trans(U32.to_nat(i), L.pow2(27n), L.pow2(30n), hc, Alloc.pow_lt(27n, 30n, {==}))
      sequence_append(C.cell_trace(i, (i << 3n : U32)), C.encode_trace(p, k, (i + 1 : U32)), Nat.mul(8n, U32.to_nat(i)), cell_sequence(i, hc),
        (%next_base(i, hc30) : Sequence(C.encode_trace(p, k, (i + 1 : U32)), _)
         encode_sequence(p, k, (i + 1 : U32),
           L.lt_rw(Nat.add(U32.to_nat((i + 1 : U32)), p), Nat.add(U32.to_nat(i), 1n+p), L.pow2(27n), sum_step(i, p, hc30), hi), hk)))

def cell_index_bound(+x: Nat, +q: Nat, +r: Nat,
  +hx: P.lt(x, L.pow2(30n)), +e: {x == Nat.add(Nat.mul(8n, q), r) : Nat}) -> P.lt(q, L.pow2(27n)):
  N.lt_of_mul_lt_mul_left(8n, q, L.pow2(27n),
    (%G.thrice(L.pow2(27n)) : P.lt(Nat.mul(8n, q), _)
     N.lt_of_le_of_lt(Nat.mul(8n, q), x, L.pow2(30n),
       (%Equal.sym(Nat, x, Nat.add(Nat.mul(8n, q), r), e) : P.le(Nat.mul(8n, q), _)
        N.le_add_right(Nat.mul(8n, q), r)), hx)))

def encoder_sequence(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) -> Sequence(C.encode_trace(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0), 0n):
  encode_sequence(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0,
    cell_index_bound(U32.to_nat(len), U32.to_nat((len >> 3n : U32)), U32.to_nat((len .&. 7 : U32)), h, G.split3(len)), G.bound3(len))

def size_append(+xs: List<&2, C.Write>, +ys: List<&2, C.Write>) -> {size(C.append(C.Write, xs, ys)) == Nat.add(size(xs), size(ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +rest}:
      Equal.cong(Nat, Nat, n => 1n+n, size(C.append(C.Write, rest, ys)), Nat.add(size(rest), size(ys)), size_append(rest, ys))

def tail_size(+n: Nat, +i: U32, +j: U32, +l: U32) -> {size(C.tail_trace(n, i, j, l)) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      Equal.cong(Nat, Nat, x => 1n+x, size(C.tail_trace(p, i, (j + 1 : U32), (l + 1 : U32))), p, tail_size(p, i, (j + 1 : U32), (l + 1 : U32)))

def encode_size(+n: Nat, +k: U32, +i: U32) -> {size(C.encode_trace(n, k, i)) == Nat.add(Nat.mul(8n, n), U32.to_nat(k)) : Nat}:
  match n:
    case 0n:
      tail_size(U32.to_nat(k), i, (i << 3n : U32), 0)
    case 1n++p:
      Equal.trans(Nat, size(C.encode_trace(1n+p, k, i)), 8n+size(C.encode_trace(p, k, (i + 1 : U32))), Nat.add(Nat.mul(8n, 1n+p), U32.to_nat(k)),
        size_append(C.cell_trace(i, (i << 3n : U32)), C.encode_trace(p, k, (i + 1 : U32))),
        Equal.trans(Nat, 8n+size(C.encode_trace(p, k, (i + 1 : U32))), 8n+Nat.add(Nat.mul(8n, p), U32.to_nat(k)), Nat.add(Nat.mul(8n, 1n+p), U32.to_nat(k)),
          Equal.cong(Nat, Nat, x => 8n+x, size(C.encode_trace(p, k, (i + 1 : U32))), Nat.add(Nat.mul(8n, p), U32.to_nat(k)), encode_size(p, k, (i + 1 : U32))),
          Equal.cong(Nat, Nat, x => Nat.add(x, U32.to_nat(k)), 8n+Nat.mul(8n, p), Nat.mul(8n, 1n+p), Equal.sym(Nat, Nat.mul(8n, 1n+p), 8n+Nat.mul(8n, p), Equal.trans(Nat, Nat.mul(8n, 1n+p), Nat.add(Nat.mul(8n, p), 8n), 8n+Nat.mul(8n, p), N.mul_succ(8n, p), N.add_comm(Nat.mul(8n, p), 8n)))))))

def encoder_location(+len: U32, +t: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n)), +ht: P.lt(U32.to_nat(t), U32.to_nat(len))) -> C.EncodeLocation(len, U32.to_nat(t), t, U32.to_nat(t)):
  +es = Equal.trans(Nat, size(C.encode_trace(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0)), Nat.add(Nat.mul(8n, U32.to_nat((len >> 3n : U32))), U32.to_nat((len .&. 7 : U32))), U32.to_nat(len), encode_size(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0), Equal.sym(Nat, U32.to_nat(len), Nat.add(Nat.mul(8n, U32.to_nat((len >> 3n : U32))), U32.to_nat((len .&. 7 : U32))), G.split3(len)))
  sequence_location(C.encode_trace(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0), U32.to_nat(t), 0n, t,
    (%Equal.sym(Nat, size(C.encode_trace(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0)), U32.to_nat(len), es) : P.lt(U32.to_nat(t), _)
     ht), N.add_zero(U32.to_nat(t)), encoder_sequence(len, h))

def DSequence(xs: List<&2, C.ReadWrite>, +b: Nat) -> Type:
  match xs:
    case Nil{}:
      Unit
    case Con{C.ReadWrite{at, j}, rest}:
      {at == b : Nat} & ({j == (U32.from_nat(b) << 3n : U32) : U32} & DSequence(rest, 1n+b))

def dsize(xs: List<&2, C.ReadWrite>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{x, rest}:
      1n+dsize(rest)

def decode_sequence(+n: Nat, +i: U32, +hi: P.le(Nat.add(U32.to_nat(i), n), L.pow2(30n))) -> DSequence(C.decode_trace(n, i), U32.to_nat(i)):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      +hc = N.lt_of_lt_of_le(U32.to_nat(i), Nat.add(U32.to_nat(i), 1n+p), L.pow2(30n), N.lt_add_of_pos_right(U32.to_nat(i), p), hi)
      ({==}, (Equal.cong(U32, U32, x => (x << 3n : U32), i, U32.from_nat(U32.to_nat(i)), Equal.sym(U32, U32.from_nat(U32.to_nat(i)), i, L.u32_from_to_nat(i))),
        (%Alloc.increment_nat(i, hc) : DSequence(C.decode_trace(p, (i + 1 : U32)), _)
         decode_sequence(p, (i + 1 : U32),
           (%Equal.sym(Nat, Nat.add(U32.to_nat((i + 1 : U32)), p), Nat.add(U32.to_nat(i), 1n+p), sum_step(i, p, hc)) : P.le(_, L.pow2(30n))
            hi)))))

def decode_size(+n: Nat, +i: U32) -> {dsize(C.decode_trace(n, i)) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      Equal.cong(Nat, Nat, x => 1n+x, dsize(C.decode_trace(p, (i + 1 : U32))), p, decode_size(p, (i + 1 : U32)))

def davoid_sequence(+xs: List<&2, C.ReadWrite>, +b: Nat, +x: Nat, +hx: P.lt(x, b), seq: DSequence(xs, b)) -> C.DecAvoid(xs, x):
  match xs:
    case Nil{}:
      Unit{}
    case Con{C.ReadWrite{+at, +j}, +rest}:
      (+ea, (ej, tail)) = seq
      ((%Equal.sym(Nat, at, b, ea) : {Nat.is_eq(x, _) == False{} : Bool}
        ne_of_lt(x, b, hx)),
       davoid_sequence(rest, 1n+b, x, N.lt_trans(x, b, 1n+b, hx, N.lt_succ_self(b)), tail))

def read_offset(+i: U32, +k: Nat, +hi: P.lt(U32.to_nat(i), L.pow2(27n)), +hk: P.lt(k, 8n)) -> {C.read_address((i << 3n : U32), k) == Nat.add(k, Nat.mul(8n, U32.to_nat(i))) : Nat}:
  match k:
    case 0n:
      shift_base(i, hi)
    case 1n:
      address_offset(i, 1n, hi, {==})
    case 2n:
      address_offset(i, 2n, hi, {==})
    case 3n:
      address_offset(i, 3n, hi, {==})
    case 4n:
      address_offset(i, 4n, hi, {==})
    case 5n:
      address_offset(i, 5n, hi, {==})
    case 6n:
      address_offset(i, 6n, hi, {==})
    case 7n:
      address_offset(i, 7n, hi, {==})
    case 8n+p:
      P.efq({C.read_address((i << 3n : U32), 8n+p) == Nat.add(8n+p, Nat.mul(8n, U32.to_nat(i))) : Nat}, P.lt_zero(p, hk))

def read_target(+t: U32, +ht: P.lt(U32.to_nat(t), L.pow2(30n))) -> {C.read_address(((t >> 3n : U32) << 3n : U32), U32.to_nat((t .&. 7 : U32))) == U32.to_nat(t) : Nat}:
  +q = U32.to_nat((t >> 3n : U32))
  +r = U32.to_nat((t .&. 7 : U32))
  Equal.trans(Nat, C.read_address(((t >> 3n : U32) << 3n : U32), r), Nat.add(r, Nat.mul(8n, q)), U32.to_nat(t),
    read_offset((t >> 3n : U32), r, cell_index_bound(U32.to_nat(t), q, r, ht, G.split3(t)), G.bound3(t)),
    Equal.trans(Nat, Nat.add(r, Nat.mul(8n, q)), Nat.add(Nat.mul(8n, q), r), U32.to_nat(t), N.add_comm(r, Nat.mul(8n, q)), Equal.sym(Nat, U32.to_nat(t), Nat.add(Nat.mul(8n, q), r), G.split3(t))))

def dsequence_location(+xs: List<&2, C.ReadWrite>, +p: Nat, +b: Nat, +t: U32,
  +hp: P.lt(p, dsize(xs)), +ex: {Nat.add(p, b) == U32.to_nat((t >> 3n : U32)) : Nat}, +ht: P.lt(U32.to_nat(t), L.pow2(30n)), seq: DSequence(xs, b)) -> C.DecLocation(xs, p, t, U32.to_nat(t), U32.to_nat((t .&. 7 : U32))):
  match xs:
    case Nil{}:
      P.efq(C.DecLocation(Nil{}, p, t, U32.to_nat(t), U32.to_nat((t .&. 7 : U32))), P.lt_zero(p, hp))
    case Con{C.ReadWrite{+at, +j}, +rest}:
      (+ea, (+ej, tail)) = seq
      match p:
        case 0n:
          +eq = Equal.trans(U32, U32.from_nat(b), U32.from_nat(U32.to_nat((t >> 3n : U32))), (t >> 3n : U32), Equal.cong(Nat, U32, U32.from_nat, b, U32.to_nat((t >> 3n : U32)), ex), L.u32_from_to_nat((t >> 3n : U32)))
          +eb = Equal.trans(U32, j, (U32.from_nat(b) << 3n : U32), ((t >> 3n : U32) << 3n : U32), ej, Equal.cong(U32, U32, x => (x << 3n : U32), U32.from_nat(b), (t >> 3n : U32), eq))
          (Equal.trans(Nat, at, b, U32.to_nat((t >> 3n : U32)), ea, ex),
           (G.bound3(t), (L.u32_from_to_nat((t .&. 7 : U32)),
             (Equal.trans(Nat, C.read_address(j, U32.to_nat((t .&. 7 : U32))), C.read_address(((t >> 3n : U32) << 3n : U32), U32.to_nat((t .&. 7 : U32))), U32.to_nat(t), Equal.cong(U32, Nat, x => C.read_address(x, U32.to_nat((t .&. 7 : U32))), j, ((t >> 3n : U32) << 3n : U32), eb), read_target(t, ht)),
              davoid_sequence(rest, 1n+b, U32.to_nat((t >> 3n : U32)),
                (%ex : P.lt(_, 1n+b)
                 N.lt_succ_self(b)), tail)))))
        case 1n++q:
          dsequence_location(rest, q, 1n+b, t, hp,
            Equal.trans(Nat, Nat.add(q, 1n+b), 1n+Nat.add(q, b), U32.to_nat((t >> 3n : U32)), Equal.sym(Nat, 1n+Nat.add(q, b), Nat.add(q, 1n+b), P.add_succ(q, b)), ex), ht, tail)

def scalar_count_bound(+len: U32, +t: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n)), +ht: P.lt(U32.to_nat(t), U32.to_nat(len))) -> P.lt(U32.to_nat((t >> 3n : U32)), U32.to_nat(A.cells(len))):
  +q = U32.to_nat((t >> 3n : U32))
  +r = U32.to_nat((t .&. 7 : U32))
  %Equal.sym(Nat, U32.to_nat(A.cells(len)), Nat.div(Nat.add(U32.to_nat(len), 7n), 8n), G.cells_nat(len, h)) : P.lt(q, _)
  %Equal.sym(Bool, Nat.is_lt(q, Nat.div(Nat.add(U32.to_nat(len), 7n), 8n)), Nat.is_lt(Nat.mul(q, 8n), U32.to_nat(len)), Alloc.ceil_cmp(q, U32.to_nat(len))) : {_ == True{} : Bool}
  N.lt_of_le_of_lt(Nat.mul(q, 8n), U32.to_nat(t), U32.to_nat(len),
    (%Equal.sym(Nat, U32.to_nat(t), Nat.add(Nat.mul(8n, q), r), G.split3(t)) : P.le(Nat.mul(q, 8n), _)
     %N.mul_comm(8n, q) : P.le(_, Nat.add(Nat.mul(8n, q), r))
     N.le_add_right(Nat.mul(8n, q), r)), ht)

def decoder_location(+len: U32, +t: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n)), +ht: P.lt(U32.to_nat(t), U32.to_nat(len))) -> C.DecodeLocation(len, U32.to_nat((t >> 3n : U32)), t, U32.to_nat(t), U32.to_nat((t .&. 7 : U32))):
  dsequence_location(C.decode_trace(U32.to_nat(A.cells(len)), 0), U32.to_nat((t >> 3n : U32)), 0n, t,
    (%Equal.sym(Nat, dsize(C.decode_trace(U32.to_nat(A.cells(len)), 0)), U32.to_nat(A.cells(len)), decode_size(U32.to_nat(A.cells(len)), 0)) : P.lt(U32.to_nat((t >> 3n : U32)), _)
     scalar_count_bound(len, t, h, ht)),
    N.add_zero(U32.to_nat((t >> 3n : U32))),
    N.lt_trans(U32.to_nat(t), U32.to_nat(len), L.pow2(30n), ht, h),
    decode_sequence(U32.to_nat(A.cells(len)), 0, Alloc.cell_count_bound(len, h)))

def pred_nat(+i: U32, +q: Nat, +ei: {U32.to_nat(i) == 1n+q : Nat}) -> {U32.to_nat((i - 1 : U32)) == q : Nat}:
  Equal.trans(Nat, U32.to_nat((i - 1 : U32)), Nat.sub(U32.to_nat(i), 1n), q,
    Alloc.decrement_nat(i,
      (%Equal.sym(Nat, U32.to_nat(i), 1n+q, ei) : P.le(1n, _)
       N.succ_le_succ(0n, q, N.zero_le(q)))),
    Equal.trans(Nat, Nat.sub(U32.to_nat(i), 1n), Nat.sub(1n+q, 1n), q, Equal.cong(Nat, Nat, x => Nat.sub(x, 1n), U32.to_nat(i), 1n+q, ei), N.sub_zero(q)))

def logical_bounds_go(+n: Nat, +i: U32, +len: U32, +e: {n == 1n+U32.to_nat(i) : Nat}, +hi: P.lt(U32.to_nat(i), U32.to_nat(len))) -> Trim.LogicalBounds(n, i, len):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      match p:
        case 0n:
          (hi, Unit{})
        case 1n++q:
          +ei = Equal.sym(Nat, 1n+q, U32.to_nat(i), P.succ_inj(1n+q, U32.to_nat(i), e))
          +ed = pred_nat(i, q, ei)
          (hi, logical_bounds_go(1n+q, (i - 1 : U32), len,
            Equal.cong(Nat, Nat, x => 1n+x, q, U32.to_nat((i - 1 : U32)), Equal.sym(Nat, U32.to_nat((i - 1 : U32)), q, ed)),
            L.lt_rw(U32.to_nat((i - 1 : U32)), q, U32.to_nat(len), ed,
              N.lt_trans(q, 1n+q, U32.to_nat(len), N.lt_succ_self(q),
                (%ei : P.lt(_, U32.to_nat(len))
                 hi)))))

def logical_bounds_nat(+n: Nat, +len: U32, +e: {U32.to_nat(len) == n : Nat}) -> Trim.LogicalBounds(n, (len - 1 : U32), len):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      +ed = pred_nat(len, p, e)
      logical_bounds_go(1n+p, (len - 1 : U32), len,
        Equal.cong(Nat, Nat, x => 1n+x, p, U32.to_nat((len - 1 : U32)), Equal.sym(Nat, U32.to_nat((len - 1 : U32)), p, ed)),
        L.lt_rw(U32.to_nat((len - 1 : U32)), p, U32.to_nat(len), ed,
          (%Equal.sym(Nat, U32.to_nat(len), 1n+p, e) : P.lt(p, _)
           N.lt_succ_self(p))))

def logical_bounds(+len: U32) -> Trim.LogicalBounds(U32.to_nat(len), (len - 1 : U32), len):
  logical_bounds_nat(U32.to_nat(len), len, {==})

def observations(n: Nat, +i: U32) -> List<&2, C.Observation>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{C.Observation{U32.to_nat(i), U32.to_nat(i), U32.to_nat((i >> 3n : U32)), U32.to_nat((i .&. 7 : U32))}, observations(p, (i - 1 : U32))}

def layout_go(+n: Nat, +i: U32, +len: U32, +words: Nat, +cells: Nat,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hw: P.le(U32.to_nat(len), words), +hc: P.le(U32.to_nat(A.cells(len)), cells), bounds: Trim.LogicalBounds(n, i, len)) -> C.Layout(n, observations(n, i), i, len, words, cells):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      (+hi, rest) = bounds
      (N.lt_of_lt_of_le(U32.to_nat(i), U32.to_nat(len), words, hi, hw),
       (N.lt_of_lt_of_le(U32.to_nat((i >> 3n : U32)), U32.to_nat(A.cells(len)), cells, scalar_count_bound(len, i, h, hi), hc),
        (encoder_location(len, i, h, hi),
         (decoder_location(len, i, h, hi),
          layout_go(p, (i - 1 : U32), len, words, cells, h, hw, hc, rest)))))

def layout(+len: U32, +words: Nat, +cells: Nat,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hw: P.le(U32.to_nat(len), words), +hc: P.le(U32.to_nat(A.cells(len)), cells)) -> C.Layout(U32.to_nat(len), observations(U32.to_nat(len), (len - 1 : U32)), (len - 1 : U32), len, words, cells):
  layout_go(U32.to_nat(len), (len - 1 : U32), len, words, cells, h, hw, hc, logical_bounds(len))

def roundtrip(+len: U32, +src: Arr.Tree<A.Cell>, +words: List<&2, U32>, +out: List<&2, A.Cell>,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hw: P.le(U32.to_nat(len), P.len(U32, 0, words)), +hc: P.le(U32.to_nat(A.cells(len)), P.len(A.Cell, A.zero(), out))) -> {C.source_list(len, src) == C.to_list(len, C.decode(len, C.encode(len, src, words), out)) : List<&2, F32>}:
  C.roundtrip_list(len, src, words, out, observations(U32.to_nat(len), (len - 1 : U32)), layout(len, P.len(U32, 0, words), P.len(A.Cell, A.zero(), out), h, hw, hc))

def eight_succ(+n: Nat) -> {Nat.mul(8n, 1n+n) == 8n+Nat.mul(8n, n) : Nat}:
  Equal.trans(Nat, Nat.mul(8n, 1n+n), Nat.add(Nat.mul(8n, n), 8n), 8n+Nat.mul(8n, n), N.mul_succ(8n, n), N.add_comm(Nat.mul(8n, n), 8n))

def offset_capacity(+d: Nat, +i: U32, +k: Nat,
  +hi: P.lt(U32.to_nat(i), L.pow2(27n)), +hk: P.lt(k, 8n),
  +room: P.le(8n+Nat.mul(8n, U32.to_nat(i)), Nat.pow(2n, d))) -> P.lt(U32.to_nat(((i << 3n : U32) + U32.from_nat(k) : U32)), Nat.pow(2n, d)):
  L.lt_rw(U32.to_nat(((i << 3n : U32) + U32.from_nat(k) : U32)), Nat.add(k, Nat.mul(8n, U32.to_nat(i))), Nat.pow(2n, d), address_offset(i, k, hi, hk),
    N.lt_of_lt_of_le(Nat.add(k, Nat.mul(8n, U32.to_nat(i))), 8n+Nat.mul(8n, U32.to_nat(i)), Nat.pow(2n, d), N.add_lt_add_right(k, 8n, Nat.mul(8n, U32.to_nat(i)), hk), room))

def eight_bounds(+d: Nat, +i: U32,
  +hi: P.lt(U32.to_nat(i), L.pow2(27n)),
  +room: P.le(8n+Nat.mul(8n, U32.to_nat(i)), Nat.pow(2n, d))) -> Bridge.EightBounds(d, (i << 3n : U32)):
  (offset_capacity(d, i, 0n, hi, {==}, room), offset_capacity(d, i, 1n, hi, {==}, room), offset_capacity(d, i, 2n, hi, {==}, room), offset_capacity(d, i, 3n, hi, {==}, room), offset_capacity(d, i, 4n, hi, {==}, room), offset_capacity(d, i, 5n, hi, {==}, room), offset_capacity(d, i, 6n, hi, {==}, room), offset_capacity(d, i, 7n, hi, {==}, room), Unit{})

def tail_bounds(+n: Nat, +j: U32, +len: U32, +d: Nat,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)),
  +budget: P.le(Nat.add(U32.to_nat(j), n), U32.to_nat(len)),
  +capacity: P.le(U32.to_nat(len), Nat.pow(2n, d))) -> Bridge.TailBounds(d, n, j):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      +hj = N.lt_of_lt_of_le(U32.to_nat(j), Nat.add(U32.to_nat(j), 1n+p), U32.to_nat(len), N.lt_add_of_pos_right(U32.to_nat(j), p), budget)
      +hj30 = N.lt_trans(U32.to_nat(j), U32.to_nat(len), L.pow2(30n), hj, h)
      (N.lt_of_lt_of_le(U32.to_nat(j), U32.to_nat(len), Nat.pow(2n, d), hj, capacity),
       tail_bounds(p, (j + 1 : U32), len, d, h,
         (%Equal.sym(Nat, Nat.add(U32.to_nat((j + 1 : U32)), p), Nat.add(U32.to_nat(j), 1n+p), sum_step(j, p, hj30)) : P.le(_, U32.to_nat(len))
          budget), capacity))

def encode_bounds_go(+n: Nat, +k: U32, +i: U32, +len: U32, +d: Nat,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hk: P.lt(U32.to_nat(k), 8n),
  +budget: P.le(Nat.add(Nat.mul(8n, Nat.add(U32.to_nat(i), n)), U32.to_nat(k)), U32.to_nat(len)),
  +capacity: P.le(U32.to_nat(len), Nat.pow(2n, d))) -> Bridge.EncodeBounds(d, n, k, i):
  +end = Nat.add(Nat.mul(8n, Nat.add(U32.to_nat(i), n)), U32.to_nat(k))
  +hs = cell_index_bound(end, Nat.add(U32.to_nat(i), n), U32.to_nat(k), N.lt_of_le_of_lt(end, U32.to_nat(len), L.pow2(30n), budget, h), {==})
  +hi = N.lt_of_le_of_lt(U32.to_nat(i), Nat.add(U32.to_nat(i), n), L.pow2(27n), N.le_add_right(U32.to_nat(i), n), hs)
  match n:
    case 0n:
      tail_bounds(U32.to_nat(k), (i << 3n : U32), len, d, h,
        (%Equal.sym(Nat, U32.to_nat((i << 3n : U32)), Nat.mul(8n, U32.to_nat(i)), shift_base(i, hi)) : P.le(Nat.add(_, U32.to_nat(k)), U32.to_nat(len))
         (%Equal.cong(Nat, Nat, x => Nat.add(Nat.mul(8n, x), U32.to_nat(k)), Nat.add(U32.to_nat(i), 0n), U32.to_nat(i), N.add_zero(U32.to_nat(i))) : P.le(_, U32.to_nat(len))
          budget)), capacity)
    case 1n++p:
      +hi30 = N.lt_trans(U32.to_nat(i), L.pow2(27n), L.pow2(30n), hi, Alloc.pow_lt(27n, 30n, {==}))
      +hnext = N.le_trans(1n+U32.to_nat(i), Nat.add(U32.to_nat(i), 1n+p), Nat.add(U32.to_nat(i), 1n+p),
        (%P.add_succ(U32.to_nat(i), p) : P.le(1n+U32.to_nat(i), _)
         N.succ_le_succ(U32.to_nat(i), Nat.add(U32.to_nat(i), p), N.le_add_right(U32.to_nat(i), p))), N.le_refl(Nat.add(U32.to_nat(i), 1n+p)))
      +room = N.le_trans(8n+Nat.mul(8n, U32.to_nat(i)), end, U32.to_nat(len),
        (%eight_succ(U32.to_nat(i)) : P.le(_, end)
         N.le_trans(Nat.mul(8n, 1n+U32.to_nat(i)), Nat.mul(8n, Nat.add(U32.to_nat(i), 1n+p)), end,
           N.mul_le_mul_left(1n+U32.to_nat(i), Nat.add(U32.to_nat(i), 1n+p), 8n, hnext),
           N.le_add_right(Nat.mul(8n, Nat.add(U32.to_nat(i), 1n+p)), U32.to_nat(k)))), budget)
      (eight_bounds(d, i, hi, N.le_trans(8n+Nat.mul(8n, U32.to_nat(i)), U32.to_nat(len), Nat.pow(2n, d), room, capacity)),
       encode_bounds_go(p, k, (i + 1 : U32), len, d, h, hk,
         (%Equal.sym(Nat, Nat.add(U32.to_nat((i + 1 : U32)), p), Nat.add(U32.to_nat(i), 1n+p), sum_step(i, p, hi30)) : P.le(Nat.add(Nat.mul(8n, _), U32.to_nat(k)), U32.to_nat(len))
          budget), capacity))

def encode_bounds(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) -> Bridge.EncodeBounds(Alloc.word_depth(len), U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0):
  encode_bounds_go(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), 0, len, Alloc.word_depth(len), h, G.bound3(len),
    (%G.split3(len) : P.le(_, U32.to_nat(len))
     N.le_refl(U32.to_nat(len))), Alloc.words_cover(len, h))

def cells27(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) -> P.le(U32.to_nat(A.cells(len)), L.pow2(27n)):
  %Equal.sym(Nat, U32.to_nat(A.cells(len)), Nat.div(Nat.add(U32.to_nat(len), 7n), 8n), G.cells_nat(len, h)) : P.le(_, L.pow2(27n))
  Alloc.ceil_pow_bound(27n, U32.to_nat(len), N.le_of_lt(U32.to_nat(len), L.pow2(30n), h))

def decode_bounds_go(+n: Nat, +i: U32, +len: U32,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +h8: P.le(8n, U32.to_nat(len)),
  +budget: P.le(Nat.add(U32.to_nat(i), n), U32.to_nat(A.cells(len)))) -> Bridge.DecodeBounds(Alloc.word_depth(len), Alloc.cell_depth(len), n, i):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      +hc = N.lt_of_lt_of_le(U32.to_nat(i), Nat.add(U32.to_nat(i), 1n+p), U32.to_nat(A.cells(len)), N.lt_add_of_pos_right(U32.to_nat(i), p), budget)
      +hi = N.lt_of_lt_of_le(U32.to_nat(i), U32.to_nat(A.cells(len)), L.pow2(27n), hc, cells27(len, h))
      +hcap = N.lt_of_lt_of_le(U32.to_nat(i), U32.to_nat(A.cells(len)), Alloc.cell_capacity(len), hc, Alloc.cells_cover(len, h))
      +room : P.le(8n+Nat.mul(8n, U32.to_nat(i)), Alloc.word_capacity(len)) = (
        %Equal.sym(Nat, Alloc.word_capacity(len), Nat.mul(8n, Alloc.cell_capacity(len)), Alloc.capacity_ratio(len, h, h8)) : P.le(8n+Nat.mul(8n, U32.to_nat(i)), _)
        %eight_succ(U32.to_nat(i)) : P.le(_, Nat.mul(8n, Alloc.cell_capacity(len)))
        N.mul_le_mul_left(1n+U32.to_nat(i), Alloc.cell_capacity(len), 8n, N.succ_le_of_lt(U32.to_nat(i), Alloc.cell_capacity(len), hcap)))
      (eight_bounds(Alloc.word_depth(len), i, hi, room), hcap,
        decode_bounds_go(p, (i + 1 : U32), len, h, h8,
          (%Equal.sym(Nat, Nat.add(U32.to_nat((i + 1 : U32)), p), Nat.add(U32.to_nat(i), 1n+p), sum_step(i, p, N.lt_trans(U32.to_nat(i), L.pow2(27n), L.pow2(30n), hi, Alloc.pow_lt(27n, 30n, {==})))) : P.le(_, U32.to_nat(A.cells(len)))
           budget)))

def decode_bounds(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n)), +h8: P.le(8n, U32.to_nat(len))) -> Bridge.DecodeBounds(Alloc.word_depth(len), Alloc.cell_depth(len), U32.to_nat(A.cells(len)), 0):
  decode_bounds_go(U32.to_nat(A.cells(len)), 0, len, h, h8, N.le_refl(U32.to_nat(A.cells(len))))

def list_bounds_go(+n: Nat, +i: U32, +len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n)), bounds: Trim.LogicalBounds(n, i, len)) -> Bridge.ListBounds(Alloc.cell_depth(len), n, i):
  match n:
    case 0n:
      Unit{}
    case 1n++p:
      (hi, rest) = bounds
      (Alloc.scalar_cell_bound(len, i, h, hi), list_bounds_go(p, (i - 1 : U32), len, h, rest))

def list_bounds(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) -> Bridge.ListBounds(Alloc.cell_depth(len), U32.to_nat(len), (len - 1 : U32)):
  list_bounds_go(U32.to_nat(len), (len - 1 : U32), len, h, logical_bounds(len))

def nonzero_positive(+n: Nat, +k: U32, +e: {U32.to_nat(k) == n : Nat}, +hn: {U32.is_ne(k, 0) == True{} : Bool}) -> P.lt(0n, n):
  match n:
    case 0n:
      +ez = L.u32_to_nat_inj(k, 0, e)
      P.efq(P.lt(0n, 0n), P.ft(
        (%ez : {U32.is_ne(_, 0) == True{} : Bool}
         hn)))
    case 1n+p:
      {==}

def positive_add(+base: Nat, +r: Nat, +hr: P.lt(0n, r)) -> P.lt(base, Nat.add(base, r)):
  match r:
    case 0n:
      P.efq(P.lt(base, Nat.add(base, 0n)), P.ft(hr))
    case 1n+p:
      N.lt_add_of_pos_right(base, p)

def trim_index_of(part: Bool, +len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n)), ep: {part == U32.is_ne((len .&. 7 : U32), 0) : Bool}) -> Trim.TrimIndex(part, len, Alloc.cell_depth(len)):
  match part:
    case False{}:
      Unit{}
    case True{}:
      +q = U32.to_nat((len >> 3n : U32))
      +r = U32.to_nat((len .&. 7 : U32))
      +hr = nonzero_positive(r, (len .&. 7 : U32), {==}, Equal.sym(Bool, True{}, U32.is_ne((len .&. 7 : U32), 0), ep))
      N.lt_of_lt_of_le(q, U32.to_nat(A.cells(len)), Alloc.cell_capacity(len),
        (%Equal.sym(Nat, U32.to_nat(A.cells(len)), Nat.div(Nat.add(U32.to_nat(len), 7n), 8n), G.cells_nat(len, h)) : P.lt(q, _)
         %Equal.sym(Bool, Nat.is_lt(q, Nat.div(Nat.add(U32.to_nat(len), 7n), 8n)), Nat.is_lt(Nat.mul(q, 8n), U32.to_nat(len)), Alloc.ceil_cmp(q, U32.to_nat(len))) : {_ == True{} : Bool}
         %Equal.sym(Nat, U32.to_nat(len), Nat.add(Nat.mul(8n, q), r), G.split3(len)) : P.lt(Nat.mul(q, 8n), _)
         %N.mul_comm(8n, q) : P.lt(_, Nat.add(Nat.mul(8n, q), r))
         positive_add(Nat.mul(8n, q), r, hr)),
        Alloc.cells_cover(len, h))

def trim_index(+len: U32, +h: P.lt(U32.to_nat(len), L.pow2(30n))) -> Trim.TrimIndex(U32.is_ne((len .&. 7 : U32), 0), len, Alloc.cell_depth(len)):
  trim_index_of(U32.is_ne((len .&. 7 : U32), 0), len, h, {==})

def element_roundtrip(+len: U32, +src: Arr.Tree<A.Cell>, +words: List<&2, U32>, +out: List<&2, A.Cell>, +i: U32,
  +h: P.lt(U32.to_nat(len), L.pow2(30n)), +hi: P.lt(U32.to_nat(i), U32.to_nat(len)),
  +hw: P.le(U32.to_nat(len), P.len(U32, 0, words)), +hc: P.le(U32.to_nat(A.cells(len)), P.len(A.Cell, A.zero(), out))) -> {C.source_peek(src, i) == C.peek(C.decode(len, C.encode(len, src, words), out), i) : F32}:
  C.roundtrip_at(len, src, words, out, i, U32.to_nat(i), U32.to_nat(i), U32.to_nat((i >> 3n : U32)), U32.to_nat((i .&. 7 : U32)),
    N.lt_of_lt_of_le(U32.to_nat(i), U32.to_nat(len), P.len(U32, 0, words), hi, hw),
    N.lt_of_lt_of_le(U32.to_nat((i >> 3n : U32)), U32.to_nat(A.cells(len)), P.len(A.Cell, A.zero(), out), scalar_count_bound(len, i, h, hi), hc),
    encoder_location(len, i, h, hi), decoder_location(len, i, h, hi))
