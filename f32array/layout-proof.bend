import Base
import ./f32array.bend as A
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import ../lemmas/lemmas.bend as L
import ../lemmas/perfect.bend as P
import bend-mathlib@0.8.0.0/nat.bend as N

def pow_bridge(+d: Nat) -> {L.pow2(d) == Nat.pow(2n, d) : Nat}:
  match d:
    case 0n:
      {==}
    case 1n++p:
      Equal.trans(Nat, Nat.double(L.pow2(p)), Nat.double(Nat.pow(2n, p)), Nat.pow(2n, 1n+p), Equal.cong(Nat, Nat, Nat.double, L.pow2(p), Nat.pow(2n, p), pow_bridge(p)), P.tps(p))

def pad_nat(n: Nat, +w: Word(n)) -> {Word.to_nat(1n+n, Word.shr.pad(n, w)) == Word.to_nat(n, w) : Nat}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+p:
      match w:
        case WCon{False{}, +t}:
          Equal.cong(Nat, Nat, Nat.double, Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t), pad_nat(p, t))
        case WCon{True{}, +t}:
          Equal.cong(Nat, Nat, n => 1n+Nat.double(n), Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t), pad_nat(p, t))

def and_zero(n: Nat, +w: Word(n)) -> {Word.and(n, w, Word.zero(n)) == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{False{}, +t}:
          Equal.cong(Word(p), Word(1n+p), x => WCon{False{}, x}, Word.and(p, t, Word.zero(p)), Word.zero(p), and_zero(p, t))
        case WCon{True{}, +t}:
          Equal.cong(Word(p), Word(1n+p), x => WCon{False{}, x}, Word.and(p, t, Word.zero(p)), Word.zero(p), and_zero(p, t))

def twice(+n: Nat) -> {Nat.double(Nat.double(n)) == Nat.mul(4n, n) : Nat}:
  Equal.trans(Nat, Nat.double(Nat.double(n)), Nat.double(Nat.mul(2n, n)), Nat.mul(4n, n), Equal.cong(Nat, Nat, Nat.double, Nat.double(n), Nat.mul(2n, n), N.double_eq_two_mul(n)), N.double_mul(2n, n))

def thrice(+n: Nat) -> {Nat.double(Nat.double(Nat.double(n))) == Nat.mul(8n, n) : Nat}:
  Equal.trans(Nat, Nat.double(Nat.double(Nat.double(n))), Nat.double(Nat.mul(4n, n)), Nat.mul(8n, n), Equal.cong(Nat, Nat, Nat.double, Nat.double(Nat.double(n)), Nat.mul(4n, n), twice(n)), N.double_mul(4n, n))

def lane2(b0: Bool, b1: Bool) -> Nat:
  L.bit(b0, L.bit(b1, 0n))

def value2(b0: Bool, b1: Bool, +n: Nat) -> {L.bit(b0, L.bit(b1, n)) == Nat.add(lane2(b0, b1), Nat.mul(4n, n)) : Nat}:
  match b0 b1:
    case False{} False{}:
      Equal.cong(Nat, Nat, x => x, Nat.double(Nat.double(n)), Nat.mul(4n, n), twice(n))
    case False{} True{}:
      Equal.cong(Nat, Nat, x => 2n+x, Nat.double(Nat.double(n)), Nat.mul(4n, n), twice(n))
    case True{} False{}:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.double(Nat.double(n)), Nat.mul(4n, n), twice(n))
    case True{} True{}:
      Equal.cong(Nat, Nat, x => 3n+x, Nat.double(Nat.double(n)), Nat.mul(4n, n), twice(n))

def lane2_bound(b0: Bool, b1: Bool) -> P.lt(lane2(b0, b1), 4n):
  match b0 b1:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def and2_bits(b0: Bool, b1: Bool) -> {Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), Word.zero(30n)}}) == lane2(b0, b1) : Nat}:
  match b0 b1:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def and2_value(b0: Bool, b1: Bool, +t: Word(30n)) -> {U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, t}}}, 3)) == lane2(b0, b1) : Nat}:
  Equal.trans(Nat, Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), Word.and(30n, t, Word.zero(30n))}}), Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), Word.zero(30n)}}), lane2(b0, b1), Equal.cong(Word(30n), Nat, x => Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), x}}), Word.and(30n, t, Word.zero(30n)), Word.zero(30n), and_zero(30n, t)), and2_bits(b0, b1))

def shr2_tail(b0: Bool, b1: Bool, +t: Word(30n)) -> {U32.to_nat(U32.shrn(U32{WCon{b0, WCon{b1, t}}}, 2n)) == Word.to_nat(30n, t) : Nat}:
  Equal.trans(Nat, Word.to_nat(32n, Word.shr.pad(31n, Word.shr.pad(30n, t))), Word.to_nat(31n, Word.shr.pad(30n, t)), Word.to_nat(30n, t), pad_nat(31n, Word.shr.pad(30n, t)), pad_nat(30n, t))

def cons_nat(+p: Nat, +b: Bool, +t: Word(p)) -> {Word.to_nat(1n+p, WCon{b, t}) == L.bit(b, Word.to_nat(p, t)) : Nat}:
  Equal.sym(Nat, L.bit(b, Word.to_nat(p, t)), Word.to_nat(1n+p, WCon{b, t}), L.to_nat_con(p, b, t))

def cons2_nat(+p: Nat, +b0: Bool, +b1: Bool, +t: Word(p)) -> {Word.to_nat(2n+p, WCon{b0, WCon{b1, t}}) == L.bit(b0, L.bit(b1, Word.to_nat(p, t))) : Nat}:
  Equal.trans(Nat, Word.to_nat(2n+p, WCon{b0, WCon{b1, t}}), L.bit(b0, Word.to_nat(1n+p, WCon{b1, t})), L.bit(b0, L.bit(b1, Word.to_nat(p, t))), cons_nat(1n+p, b0, WCon{b1, t}), Equal.cong(Nat, Nat, x => L.bit(b0, x), Word.to_nat(1n+p, WCon{b1, t}), L.bit(b1, Word.to_nat(p, t)), cons_nat(p, b1, t)))

def cons3_nat(+p: Nat, +b0: Bool, +b1: Bool, +b2: Bool, +t: Word(p)) -> {Word.to_nat(3n+p, WCon{b0, WCon{b1, WCon{b2, t}}}) == L.bit(b0, L.bit(b1, L.bit(b2, Word.to_nat(p, t)))) : Nat}:
  Equal.trans(Nat, Word.to_nat(3n+p, WCon{b0, WCon{b1, WCon{b2, t}}}), L.bit(b0, Word.to_nat(2n+p, WCon{b1, WCon{b2, t}})), L.bit(b0, L.bit(b1, L.bit(b2, Word.to_nat(p, t)))), cons_nat(2n+p, b0, WCon{b1, WCon{b2, t}}), Equal.cong(Nat, Nat, x => L.bit(b0, x), Word.to_nat(2n+p, WCon{b1, WCon{b2, t}}), L.bit(b1, L.bit(b2, Word.to_nat(p, t))), cons2_nat(p, b1, b2, t)))

def split2(+i: U32) -> {U32.to_nat(i) == Nat.add(Nat.mul(4n, U32.to_nat(U32.shrn(i, 2n))), U32.to_nat(U32.and(i, 3))) : Nat}:
  match i:
    case U32{WCon{b0, WCon{b1, t}}}:
      %Equal.sym(Nat, U32.to_nat(U32.shrn(U32{WCon{b0, WCon{b1, t}}}, 2n)), Word.to_nat(30n, t), shr2_tail(b0, b1, t)) : {U32.to_nat(U32{WCon{b0, WCon{b1, t}}}) == Nat.add(Nat.mul(4n, _), U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, t}}}, 3))) : Nat}
      %Equal.sym(Nat, U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, t}}}, 3)), lane2(b0, b1), and2_value(b0, b1, t)) : {U32.to_nat(U32{WCon{b0, WCon{b1, t}}}) == Nat.add(Nat.mul(4n, Word.to_nat(30n, t)), _) : Nat}
      Equal.trans(Nat, U32.to_nat(U32{WCon{b0, WCon{b1, t}}}), Nat.add(lane2(b0, b1), Nat.mul(4n, Word.to_nat(30n, t))), Nat.add(Nat.mul(4n, Word.to_nat(30n, t)), lane2(b0, b1)), Equal.trans(Nat, U32.to_nat(U32{WCon{b0, WCon{b1, t}}}), L.bit(b0, L.bit(b1, Word.to_nat(30n, t))), Nat.add(lane2(b0, b1), Nat.mul(4n, Word.to_nat(30n, t))), cons2_nat(30n, b0, b1, t), value2(b0, b1, Word.to_nat(30n, t))), N.add_comm(lane2(b0, b1), Nat.mul(4n, Word.to_nat(30n, t))))

def bound2(+i: U32) -> P.lt(U32.to_nat(U32.and(i, 3)), 4n):
  match i:
    case U32{WCon{b0, WCon{b1, t}}}:
      %Equal.sym(Nat, U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, t}}}, 3)), lane2(b0, b1), and2_value(b0, b1, t)) : P.lt(_, 4n)
      lane2_bound(b0, b1)

def lane3(b0: Bool, b1: Bool, b2: Bool) -> Nat:
  L.bit(b0, L.bit(b1, L.bit(b2, 0n)))

def value3(b0: Bool, b1: Bool, b2: Bool, +n: Nat) -> {L.bit(b0, L.bit(b1, L.bit(b2, n))) == Nat.add(lane3(b0, b1, b2), Nat.mul(8n, n)) : Nat}:
  match b0 b1 b2:
    case False{} False{} False{}:
      Equal.cong(Nat, Nat, x => x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))
    case False{} False{} True{}:
      Equal.cong(Nat, Nat, x => 4n+x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))
    case False{} True{} False{}:
      Equal.cong(Nat, Nat, x => 2n+x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))
    case False{} True{} True{}:
      Equal.cong(Nat, Nat, x => 6n+x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))
    case True{} False{} False{}:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))
    case True{} False{} True{}:
      Equal.cong(Nat, Nat, x => 5n+x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))
    case True{} True{} False{}:
      Equal.cong(Nat, Nat, x => 3n+x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))
    case True{} True{} True{}:
      Equal.cong(Nat, Nat, x => 7n+x, Nat.double(Nat.double(Nat.double(n))), Nat.mul(8n, n), thrice(n))

def lane3_bound(b0: Bool, b1: Bool, b2: Bool) -> P.lt(lane3(b0, b1, b2), 8n):
  match b0 b1 b2:
    case False{} False{} False{}:
      {==}
    case False{} False{} True{}:
      {==}
    case False{} True{} False{}:
      {==}
    case False{} True{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} True{} False{}:
      {==}
    case True{} True{} True{}:
      {==}

def and3_bits(b0: Bool, b1: Bool, b2: Bool) -> {Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), WCon{Bool.and(b2, True{}), Word.zero(29n)}}}) == lane3(b0, b1, b2) : Nat}:
  match b0 b1 b2:
    case False{} False{} False{}:
      {==}
    case False{} False{} True{}:
      {==}
    case False{} True{} False{}:
      {==}
    case False{} True{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} True{} False{}:
      {==}
    case True{} True{} True{}:
      {==}

def and3_value(b0: Bool, b1: Bool, b2: Bool, +t: Word(29n)) -> {U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}, 7)) == lane3(b0, b1, b2) : Nat}:
  Equal.trans(Nat, Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), WCon{Bool.and(b2, True{}), Word.and(29n, t, Word.zero(29n))}}}), Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), WCon{Bool.and(b2, True{}), Word.zero(29n)}}}), lane3(b0, b1, b2), Equal.cong(Word(29n), Nat, x => Word.to_nat(32n, WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), WCon{Bool.and(b2, True{}), x}}}), Word.and(29n, t, Word.zero(29n)), Word.zero(29n), and_zero(29n, t)), and3_bits(b0, b1, b2))

def shr3_tail(b0: Bool, b1: Bool, b2: Bool, +t: Word(29n)) -> {U32.to_nat(U32.shrn(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}, 3n)) == Word.to_nat(29n, t) : Nat}:
  Equal.trans(Nat, Word.to_nat(32n, Word.shr.pad(31n, Word.shr.pad(30n, Word.shr.pad(29n, t)))), Word.to_nat(31n, Word.shr.pad(30n, Word.shr.pad(29n, t))), Word.to_nat(29n, t), pad_nat(31n, Word.shr.pad(30n, Word.shr.pad(29n, t))), Equal.trans(Nat, Word.to_nat(31n, Word.shr.pad(30n, Word.shr.pad(29n, t))), Word.to_nat(30n, Word.shr.pad(29n, t)), Word.to_nat(29n, t), pad_nat(30n, Word.shr.pad(29n, t)), pad_nat(29n, t)))

def split3(+i: U32) -> {U32.to_nat(i) == Nat.add(Nat.mul(8n, U32.to_nat(U32.shrn(i, 3n))), U32.to_nat(U32.and(i, 7))) : Nat}:
  match i:
    case U32{WCon{b0, WCon{b1, WCon{b2, t}}}}:
      %Equal.sym(Nat, U32.to_nat(U32.shrn(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}, 3n)), Word.to_nat(29n, t), shr3_tail(b0, b1, b2, t)) : {U32.to_nat(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}) == Nat.add(Nat.mul(8n, _), U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}, 7))) : Nat}
      %Equal.sym(Nat, U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}, 7)), lane3(b0, b1, b2), and3_value(b0, b1, b2, t)) : {U32.to_nat(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}) == Nat.add(Nat.mul(8n, Word.to_nat(29n, t)), _) : Nat}
      Equal.trans(Nat, U32.to_nat(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}), Nat.add(lane3(b0, b1, b2), Nat.mul(8n, Word.to_nat(29n, t))), Nat.add(Nat.mul(8n, Word.to_nat(29n, t)), lane3(b0, b1, b2)), Equal.trans(Nat, U32.to_nat(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}), L.bit(b0, L.bit(b1, L.bit(b2, Word.to_nat(29n, t)))), Nat.add(lane3(b0, b1, b2), Nat.mul(8n, Word.to_nat(29n, t))), cons3_nat(29n, b0, b1, b2, t), value3(b0, b1, b2, Word.to_nat(29n, t))), N.add_comm(lane3(b0, b1, b2), Nat.mul(8n, Word.to_nat(29n, t))))

def bound3(+i: U32) -> P.lt(U32.to_nat(U32.and(i, 7)), 8n):
  match i:
    case U32{WCon{b0, WCon{b1, WCon{b2, t}}}}:
      %Equal.sym(Nat, U32.to_nat(U32.and(U32{WCon{b0, WCon{b1, WCon{b2, t}}}}, 7)), lane3(b0, b1, b2), and3_value(b0, b1, b2, t)) : P.lt(_, 8n)
      lane3_bound(b0, b1, b2)

def quotient(+x: Nat, +q: Nat, +r: Nat, +k: Nat, e: {x == Nat.add(Nat.mul(1n+k, q), r) : Nat}, hr: P.lt(r, 1n+k)) -> {Nat.div(x, 1n+k) == q : Nat}:
  %Equal.sym(Nat, x, Nat.add(Nat.mul(1n+k, q), r), e) : {Nat.div(_, 1n+k) == q : Nat}
  %N.add_comm(r, Nat.mul(1n+k, q)) : {Nat.div(_, 1n+k) == q : Nat}
  Equal.trans(Nat, Nat.div(Nat.add(r, Nat.mul(1n+k, q)), 1n+k), Nat.add(Nat.div(r, 1n+k), q), q, N.add_mul_div_left(r, q, k), Equal.cong(Nat, Nat, a => Nat.add(a, q), Nat.div(r, 1n+k), 0n, N.div_eq_zero_of_le(r, k, N.le_of_lt_succ(r, k, hr))))

def shr2_nat(+i: U32) -> {U32.to_nat(U32.shrn(i, 2n)) == Nat.div(U32.to_nat(i), 4n) : Nat}:
  Equal.sym(Nat, Nat.div(U32.to_nat(i), 4n), U32.to_nat(U32.shrn(i, 2n)), quotient(U32.to_nat(i), U32.to_nat(U32.shrn(i, 2n)), U32.to_nat(U32.and(i, 3)), 3n, split2(i), bound2(i)))

def shr3_nat(+i: U32) -> {U32.to_nat(U32.shrn(i, 3n)) == Nat.div(U32.to_nat(i), 8n) : Nat}:
  Equal.sym(Nat, Nat.div(U32.to_nat(i), 8n), U32.to_nat(U32.shrn(i, 3n)), quotient(U32.to_nat(i), U32.to_nat(U32.shrn(i, 3n)), U32.to_nat(U32.and(i, 7)), 7n, split3(i), bound3(i)))

def widen(+a: Nat, +d: Nat, h: P.lt(a, L.pow2(d))) -> P.lt(a, L.pow2(1n+d)):
  N.lt_of_lt_of_le(a, L.pow2(d), Nat.double(L.pow2(d)), h, N.le_double(L.pow2(d)))

def scaled_offset(+a: Nat, +cap: Nat, +k: Nat, +r: Nat, h: P.lt(a, cap), hr: P.lt(r, k)) -> P.lt(Nat.add(Nat.mul(k, a), r), Nat.mul(k, cap)):
  N.lt_of_lt_of_le(Nat.add(Nat.mul(k, a), r), Nat.add(Nat.mul(k, a), k), Nat.mul(k, cap), N.add_lt_add_left(r, k, Nat.mul(k, a), hr), (
    %N.mul_succ(k, a) : P.le(_, Nat.mul(k, cap))
    N.mul_le_mul_left(1n+a, cap, k, N.succ_le_of_lt(a, cap, h))))

# Keep power bounds folded: https://github.com/bendlang/bend/issues/1071.
def pow_once(-d: Nat) -> {Nat.double(L.pow2(d)) == L.pow2(1n+d) : Nat}:
  {==}

def pow_twice(-d: Nat) -> {Nat.double(Nat.double(L.pow2(d))) == L.pow2(2n+d) : Nat}:
  {==}

def pow_thrice(-d: Nat) -> {Nat.double(Nat.double(Nat.double(L.pow2(d)))) == L.pow2(3n+d) : Nat}:
  {==}

def upper_rw(-a: Nat, -b: Nat, -c: Nat, e: {b == c : Nat}, h: P.lt(a, b)) -> P.lt(a, c):
  %e : P.lt(a, _)
  h

def bound4_general(+a: Nat, +cap: Nat, +max: Nat, h: P.lt(a, cap), e: {Nat.double(Nat.double(cap)) == max : Nat}) -> P.lt(Nat.mul(4n, a), max):
  upper_rw(Nat.mul(4n, a), Nat.double(Nat.double(cap)), max, e, upper_rw(Nat.mul(4n, a), Nat.mul(4n, cap), Nat.double(Nat.double(cap)), Equal.sym(Nat, Nat.double(Nat.double(cap)), Nat.mul(4n, cap), twice(cap)), N.mul_lt_mul_of_pos_left(a, cap, 3n, h)))

def offset4_general(+a: Nat, +cap: Nat, +max: Nat, +r: Nat, h: P.lt(a, cap), hr: P.lt(r, 4n), e: {Nat.double(Nat.double(cap)) == max : Nat}) -> P.lt(Nat.add(Nat.mul(4n, a), r), max):
  upper_rw(Nat.add(Nat.mul(4n, a), r), Nat.double(Nat.double(cap)), max, e, upper_rw(Nat.add(Nat.mul(4n, a), r), Nat.mul(4n, cap), Nat.double(Nat.double(cap)), Equal.sym(Nat, Nat.double(Nat.double(cap)), Nat.mul(4n, cap), twice(cap)), scaled_offset(a, cap, 4n, r, h, hr)))

def bound8_general(+a: Nat, +cap: Nat, +max: Nat, h: P.lt(a, cap), e: {Nat.double(Nat.double(Nat.double(cap))) == max : Nat}) -> P.lt(Nat.mul(8n, a), max):
  upper_rw(Nat.mul(8n, a), Nat.double(Nat.double(Nat.double(cap))), max, e, upper_rw(Nat.mul(8n, a), Nat.mul(8n, cap), Nat.double(Nat.double(Nat.double(cap))), Equal.sym(Nat, Nat.double(Nat.double(Nat.double(cap))), Nat.mul(8n, cap), thrice(cap)), N.mul_lt_mul_of_pos_left(a, cap, 7n, h)))

def offset8_general(+a: Nat, +cap: Nat, +max: Nat, +r: Nat, h: P.lt(a, cap), hr: P.lt(r, 8n), e: {Nat.double(Nat.double(Nat.double(cap))) == max : Nat}) -> P.lt(Nat.add(Nat.mul(8n, a), r), max):
  upper_rw(Nat.add(Nat.mul(8n, a), r), Nat.double(Nat.double(Nat.double(cap))), max, e, upper_rw(Nat.add(Nat.mul(8n, a), r), Nat.mul(8n, cap), Nat.double(Nat.double(Nat.double(cap))), Equal.sym(Nat, Nat.double(Nat.double(Nat.double(cap))), Nat.mul(8n, cap), thrice(cap)), scaled_offset(a, cap, 8n, r, h, hr)))

def double_sum_bound(+a: Nat, +cap: Nat, +max: Nat, e: {Nat.double(cap) == max : Nat}, h: P.lt(a, Nat.add(cap, cap))) -> P.lt(a, max):
  upper_rw(a, Nat.double(cap), max, e, upper_rw(a, Nat.add(cap, cap), Nat.double(cap), Equal.sym(Nat, Nat.double(cap), Nat.add(cap, cap), N.double_eq_add(cap)), h))

def bound4(+a: Nat, h: P.lt(a, L.pow2(30n))) -> P.lt(Nat.mul(4n, a), L.pow2(32n)):
  bound4_general(a, L.pow2(30n), L.pow2(32n), h, pow_twice(30n))

def offset4(+a: Nat, +r: Nat, h: P.lt(a, L.pow2(30n)), hr: P.lt(r, 4n)) -> P.lt(Nat.add(Nat.mul(4n, a), r), L.pow2(32n)):
  offset4_general(a, L.pow2(30n), L.pow2(32n), r, h, hr, pow_twice(30n))

# Use explicit order adapters instead of normalization: https://github.com/bendlang/bend/issues/1071.
def nat_lt(-a: Nat, -b: Nat, h: P.lt(a, b)) -> N.lt(a, b):
  h

def proof_lt(-a: Nat, -b: Nat, h: N.lt(a, b)) -> P.lt(a, b):
  h

def move_lt(-a: Nat, -b: Nat, -c: Nat, e: {a == b : Nat}, h: P.lt(b, c)) -> P.lt(a, c):
  %Equal.sym(Nat, a, b, e) : P.lt(_, c)
  h

def word_shl_exact(+n: Nat, +w: Word(n), h: N.lt(Nat.double(Word.to_nat(n, w)), L.pow2(n))) -> {Word.to_nat(n, Word.shl(n, w)) == Nat.double(Word.to_nat(n, w)) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++p:
      match w:
        case WCon{+b, +t}:
          L.add_no_carry(L.shl_carry(1n+p, False{}, WCon{b, t}), Word.to_nat(1n+p, Word.shl.put(1n+p, False{}, WCon{b, t})), L.pow2(1n+p), Nat.double(Word.to_nat(1n+p, WCon{b, t})), L.word_shl_put_nat(1n+p, False{}, WCon{b, t}), h)

def shl_exact(+i: U32, h: P.lt(Nat.double(U32.to_nat(i)), L.pow2(32n))) -> {U32.to_nat(U32.shl(i)) == Nat.double(U32.to_nat(i)) : Nat}:
  match i:
    case U32{+w}:
      word_shl_exact(32n, w, L.lt_rw(Nat.double(Word.to_nat(32n, w)), Nat.double(U32.to_nat(U32{w})), L.pow2(32n), Equal.cong(Nat, Nat, Nat.double, Word.to_nat(32n, w), U32.to_nat(U32{w}), L.u32_to_nat_word(w)), nat_lt(Nat.double(U32.to_nat(U32{w})), L.pow2(32n), h)))

def shl2_exact(+i: U32, +h: P.lt(Nat.mul(4n, U32.to_nat(i)), L.pow2(32n))) -> {U32.to_nat(U32.shln(i, 2n)) == Nat.mul(4n, U32.to_nat(i)) : Nat}:
  +v = U32.to_nat(i)
  +h2 : P.lt(Nat.double(Nat.double(v)), L.pow2(32n)) = (
    %Equal.sym(Nat, Nat.double(Nat.double(v)), Nat.mul(4n, v), twice(v)) : P.lt(_, L.pow2(32n))
    h)
  +h1 = proof_lt(Nat.double(v), L.pow2(32n), N.lt_of_le_of_lt(Nat.double(v), Nat.double(Nat.double(v)), L.pow2(32n), N.le_double(Nat.double(v)), nat_lt(Nat.double(Nat.double(v)), L.pow2(32n), h2)))
  +e1 = shl_exact(i, h1)
  +e2 = shl_exact(U32.shl(i), move_lt(Nat.double(U32.to_nat(U32.shl(i))), Nat.double(Nat.double(v)), L.pow2(32n), Equal.cong(Nat, Nat, Nat.double, U32.to_nat(U32.shl(i)), Nat.double(v), e1), h2))
  Equal.trans(Nat, U32.to_nat(U32.shln(i, 2n)), Nat.double(U32.to_nat(U32.shl(i))), Nat.mul(4n, v), e2, Equal.trans(Nat, Nat.double(U32.to_nat(U32.shl(i))), Nat.double(Nat.double(v)), Nat.mul(4n, v), Equal.cong(Nat, Nat, Nat.double, U32.to_nat(U32.shl(i)), Nat.double(v), e1), twice(v)))

def shl3_exact(+i: U32, +h: P.lt(Nat.mul(8n, U32.to_nat(i)), L.pow2(32n))) -> {U32.to_nat(U32.shln(i, 3n)) == Nat.mul(8n, U32.to_nat(i)) : Nat}:
  +v = U32.to_nat(i)
  +h8 : P.lt(Nat.double(Nat.mul(4n, v)), L.pow2(32n)) = (
    %Equal.sym(Nat, Nat.double(Nat.mul(4n, v)), Nat.mul(8n, v), N.double_mul(4n, v)) : P.lt(_, L.pow2(32n))
    h)
  +h4 = proof_lt(Nat.mul(4n, v), L.pow2(32n), N.lt_of_le_of_lt(Nat.mul(4n, v), Nat.double(Nat.mul(4n, v)), L.pow2(32n), N.le_double(Nat.mul(4n, v)), nat_lt(Nat.double(Nat.mul(4n, v)), L.pow2(32n), h8)))
  +e2 = shl2_exact(i, h4)
  +e3 = shl_exact(U32.shln(i, 2n), move_lt(Nat.double(U32.to_nat(U32.shln(i, 2n))), Nat.double(Nat.mul(4n, v)), L.pow2(32n), Equal.cong(Nat, Nat, Nat.double, U32.to_nat(U32.shln(i, 2n)), Nat.mul(4n, v), e2), h8))
  Equal.trans(Nat, U32.to_nat(U32.shln(i, 3n)), Nat.double(U32.to_nat(U32.shln(i, 2n))), Nat.mul(8n, v), e3, Equal.trans(Nat, Nat.double(U32.to_nat(U32.shln(i, 2n))), Nat.double(Nat.mul(4n, v)), Nat.mul(8n, v), Equal.cong(Nat, Nat, Nat.double, U32.to_nat(U32.shln(i, 2n)), Nat.mul(4n, v), e2), N.double_mul(4n, v)))

def address(+i: U32, +lane: U32, +h: P.lt(U32.to_nat(i), L.pow2(27n)), +hl: P.lt(U32.to_nat(lane), 8n)) -> {U32.to_nat(U32.add(U32.shln(i, 3n), lane)) == Nat.add(Nat.mul(8n, U32.to_nat(i)), U32.to_nat(lane)) : Nat}:
  +v = U32.to_nat(i)
  +h29 = widen(v, 28n, widen(v, 27n, h))
  +hb = offset8_general(v, L.pow2(29n), L.pow2(32n), U32.to_nat(lane), h29, hl, pow_thrice(29n))
  +h8 = bound8_general(v, L.pow2(29n), L.pow2(32n), h29, pow_thrice(29n))
  +e = shl3_exact(i, h8)
  Equal.trans(Nat, U32.to_nat(U32.add(U32.shln(i, 3n), lane)), Nat.add(U32.to_nat(U32.shln(i, 3n)), U32.to_nat(lane)), Nat.add(Nat.mul(8n, v), U32.to_nat(lane)), L.u32_add_nat(U32.shln(i, 3n), lane, L.lt_rw(Nat.add(U32.to_nat(U32.shln(i, 3n)), U32.to_nat(lane)), Nat.add(Nat.mul(8n, v), U32.to_nat(lane)), L.pow2(32n), Equal.cong(Nat, Nat, a => Nat.add(a, U32.to_nat(lane)), U32.to_nat(U32.shln(i, 3n)), Nat.mul(8n, v), e), nat_lt(Nat.add(Nat.mul(8n, v), U32.to_nat(lane)), L.pow2(32n), hb))), Equal.cong(Nat, Nat, a => Nat.add(a, U32.to_nat(lane)), U32.to_nat(U32.shln(i, 3n)), Nat.mul(8n, v), e))

def add7_bound(+n: Nat, h: P.lt(n, L.pow2(30n))) -> P.lt(Nat.add(n, 7n), L.pow2(32n)):
  +h7 = upper_rw(7n, Nat.pow(2n, 30n), L.pow2(30n), Equal.sym(Nat, L.pow2(30n), Nat.pow(2n, 30n), pow_bridge(30n)), proof_lt(7n, Nat.pow(2n, 30n), N.lt_of_lt_of_le(7n, 8n, Nat.pow(2n, 30n), {==}, N.pow_le_pow_right(1n, 3n, 30n, {==}))))
  +hs = N.add_lt_add(n, 7n, L.pow2(30n), L.pow2(30n), nat_lt(n, L.pow2(30n), h), nat_lt(7n, L.pow2(30n), h7))
  +hd = double_sum_bound(Nat.add(n, 7n), L.pow2(30n), L.pow2(31n), pow_once(30n), proof_lt(Nat.add(n, 7n), Nat.add(L.pow2(30n), L.pow2(30n)), hs))
  widen(Nat.add(n, 7n), 31n, hd)

# Split arithmetic transports to avoid checker expansion: https://github.com/bendlang/bend/issues/1071.
def add7_exact(+n: U32, h: N.lt(Nat.add(U32.to_nat(n), 7n), L.pow2(32n))) -> {U32.to_nat(U32.add(n, 7)) == Nat.add(U32.to_nat(n), 7n) : Nat}:
  L.u32_add_nat(n, 7, L.lt_rw(Nat.add(U32.to_nat(n), U32.to_nat(7)), Nat.add(U32.to_nat(n), 7n), L.pow2(32n), Equal.cong(Nat, Nat, k => Nat.add(U32.to_nat(n), k), U32.to_nat(7), 7n, {==}), h))

def divide8_equal(+a: Nat, +b: Nat, e: {a == b : Nat}) -> {Nat.div(a, 8n) == Nat.div(b, 8n) : Nat}:
  Equal.cong(Nat, Nat, a => Nat.div(a, 8n), a, b, e)

def cells_nat(+n: U32, +h: P.lt(U32.to_nat(n), L.pow2(30n))) -> {U32.to_nat(A.cells(n)) == Nat.div(Nat.add(U32.to_nat(n), 7n), 8n) : Nat}:
  +hb = nat_lt(Nat.add(U32.to_nat(n), 7n), L.pow2(32n), add7_bound(U32.to_nat(n), h))
  +ea = add7_exact(n, hb)
  +ed = divide8_equal(U32.to_nat(U32.add(n, 7)), Nat.add(U32.to_nat(n), 7n), ea)
  Equal.trans(Nat, U32.to_nat(A.cells(n)), Nat.div(U32.to_nat(U32.add(n, 7)), 8n), Nat.div(Nat.add(U32.to_nat(n), 7n), 8n), shr3_nat(U32.add(n, 7)), ed)

# Keep literal conversion outside the bound: https://github.com/bendlang/bend/issues/1071.
def add3_exact(+n: U32, h: N.lt(Nat.add(U32.to_nat(n), 3n), L.pow2(32n))) -> {U32.to_nat(U32.add(n, 3)) == Nat.add(U32.to_nat(n), 3n) : Nat}:
  L.u32_add_nat(n, 3, L.lt_rw(Nat.add(U32.to_nat(n), U32.to_nat(3)), Nat.add(U32.to_nat(n), 3n), L.pow2(32n), Equal.cong(Nat, Nat, k => Nat.add(U32.to_nat(n), k), U32.to_nat(3), 3n, {==}), h))

def words_nat(+n: U32, +h: P.lt(U32.to_nat(n), L.pow2(30n))) -> {U32.to_nat(Bytes.words(U32.shln(n, 2n))) == U32.to_nat(n) : Nat}:
  +v = U32.to_nat(n)
  +es = shl2_exact(n, bound4(v, h))
  +ea = add3_exact(U32.shln(n, 2n), L.lt_rw(Nat.add(U32.to_nat(U32.shln(n, 2n)), 3n), Nat.add(Nat.mul(4n, v), 3n), L.pow2(32n), Equal.cong(Nat, Nat, a => Nat.add(a, 3n), U32.to_nat(U32.shln(n, 2n)), Nat.mul(4n, v), es), nat_lt(Nat.add(Nat.mul(4n, v), 3n), L.pow2(32n), offset4(v, 3n, h, {==}))))
  +e = Equal.trans(Nat, U32.to_nat(U32.add(U32.shln(n, 2n), 3)), Nat.add(U32.to_nat(U32.shln(n, 2n)), 3n), Nat.add(Nat.mul(4n, v), 3n), ea, Equal.cong(Nat, Nat, a => Nat.add(a, 3n), U32.to_nat(U32.shln(n, 2n)), Nat.mul(4n, v), es))
  Equal.trans(Nat, U32.to_nat(Bytes.words(U32.shln(n, 2n))), Nat.div(U32.to_nat(U32.add(U32.shln(n, 2n), 3)), 4n), v, shr2_nat(U32.add(U32.shln(n, 2n), 3)), Equal.trans(Nat, Nat.div(U32.to_nat(U32.add(U32.shln(n, 2n), 3)), 4n), Nat.div(Nat.add(Nat.mul(4n, v), 3n), 4n), v, Equal.cong(Nat, Nat, a => Nat.div(a, 4n), U32.to_nat(U32.add(U32.shln(n, 2n), 3)), Nat.add(Nat.mul(4n, v), 3n), e), quotient(Nat.add(Nat.mul(4n, v), 3n), v, 3n, 3n, {==}, {==})))

# Transport the zero literal before its bound: https://github.com/bendlang/bend/issues/1071.
def add_zero_sum(+i: U32) -> {Nat.add(U32.to_nat(i), U32.to_nat(0)) == U32.to_nat(i) : Nat}:
  Equal.trans(Nat, Nat.add(U32.to_nat(i), U32.to_nat(0)), Nat.add(U32.to_nat(i), 0n), U32.to_nat(i), Equal.cong(Nat, Nat, k => Nat.add(U32.to_nat(i), k), U32.to_nat(0), 0n, {==}), N.add_zero(U32.to_nat(i)))

def add_zero_nat(+i: U32) -> {U32.to_nat((i + 0 : U32)) == U32.to_nat(i) : Nat}:
  Equal.trans(Nat, U32.to_nat((i + 0 : U32)), Nat.add(U32.to_nat(i), U32.to_nat(0)), U32.to_nat(i), L.u32_add_nat(i, 0, L.lt_rw(Nat.add(U32.to_nat(i), U32.to_nat(0)), U32.to_nat(i), L.pow2(32n), add_zero_sum(i), L.u32_to_nat_lt(i))), add_zero_sum(i))

def unshift2(+n: U32, +h: P.lt(U32.to_nat(n), L.pow2(30n))) -> {U32.shrn(U32.shln(n, 2n), 2n) == n : U32}:
  +v = U32.to_nat(n)
  +es = shl2_exact(n, bound4(v, h))
  L.u32_to_nat_inj(U32.shrn(U32.shln(n, 2n), 2n), n, Equal.trans(Nat, U32.to_nat(U32.shrn(U32.shln(n, 2n), 2n)), Nat.div(U32.to_nat(U32.shln(n, 2n)), 4n), v, shr2_nat(U32.shln(n, 2n)), Equal.trans(Nat, Nat.div(U32.to_nat(U32.shln(n, 2n)), 4n), Nat.div(Nat.mul(4n, v), 4n), v, Equal.cong(Nat, Nat, a => Nat.div(a, 4n), U32.to_nat(U32.shln(n, 2n)), Nat.mul(4n, v), es), quotient(Nat.mul(4n, v), v, 0n, 3n, N.add_zero_sym(Nat.mul(4n, v)), {==}))))

def aligned2(+n: U32) -> {U32.is_eq(U32.and(U32.shln(n, 2n), 3), 0) == True{} : Bool}:
  match n:
    case U32{WCon{b0, WCon{b1, +t}}}:
      %Equal.sym(Word(30n), Word.and(30n, Word.shl.put(30n, b0, Word.shl.put(30n, b1, t)), Word.zero(30n)), Word.zero(30n), and_zero(30n, Word.shl.put(30n, b0, Word.shl.put(30n, b1, t)))) : {U32.is_eq(U32{WCon{False{}, WCon{False{}, _}}}, 0) == True{} : Bool}
      {==}
