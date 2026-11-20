import Base
import ../lemmas/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./bytes.bend as Bytes

def quotient(+n: U32) -> U32:
  U32.div(n, 10)

def divide(f: Nat, n: U32) -> U32:
  match f:
    case 0n:
      n
    case 1n+p:
      divide(p, quotient(n))

def divide_le(f: Nat, +a: U32, +b: U32, h: {U32.is_le(a, b) == True{} : Bool}) -> {U32.is_le(divide(f, a), divide(f, b)) == True{} : Bool}:
  match f:
    case 0n:
      h
    case 1n+p:
      +hn = Equal.trans(Bool, Nat.is_le(U32.to_nat(a), U32.to_nat(b)), U32.is_le(a, b), True{}, Equal.sym(Bool, U32.is_le(a, b), Nat.is_le(U32.to_nat(a), U32.to_nat(b)), Lemmas.u32_is_le_nat(a, b)), h)
      +hd = MNat.div_le_div(U32.to_nat(a), U32.to_nat(b), 9n, hn)
      +ha = Lemmas.u32_div_nat(a, 10, {==})
      +hb = Lemmas.u32_div_nat(b, 10, {==})
      divide_le(p, quotient(a), quotient(b),
        Equal.trans(Bool, U32.is_le(quotient(a), quotient(b)), Nat.is_le(U32.to_nat(quotient(a)), U32.to_nat(quotient(b))), True{}, Lemmas.u32_is_le_nat(quotient(a), quotient(b)),
          (%Equal.sym(Nat, U32.to_nat(quotient(a)), Nat.div(U32.to_nat(a), 10n), ha) : {Nat.is_le(_, U32.to_nat(quotient(b))) == True{} : Bool}
           %Equal.sym(Nat, U32.to_nat(quotient(b)), Nat.div(U32.to_nat(b), 10n), hb) : {Nat.is_le(Nat.div(U32.to_nat(a), 10n), _) == True{} : Bool}
           hd)))

def ones(n: Nat) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      WCon{True{}, ones(p)}

def reject_true(b: Bool) -> Type:
  match b:
    case False{}:
      Unit
    case True{}:
      Empty

def false_true(h: {False{} == True{} : Bool}) -> Empty:
  %h : reject_true(_)
  Unit{}

def cmp_max_fin(t: Cmp, b: Bool, h: {Cmp.is_le(t) == True{} : Bool}) -> {Cmp.is_le(Word.cmp.fin(b, True{}, t)) == True{} : Bool}:
  match t:
    case LT{}:
      {==}
    case EQ{}:
      match b:
        case False{}:
          {==}
        case True{}:
          {==}
    case GT{}:
      Empty.absurd({Cmp.is_le(Word.cmp.fin(b, True{}, GT{})) == True{} : Bool}, false_true(h))

def word_le_ones(+n: Nat, w: Word(n)) -> {Cmp.is_le(Word.cmp(n, w, ones(n))) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{+b, +t}:
          cmp_max_fin(Word.cmp(p, t, ones(p)), b, word_le_ones(p, t))

def u32_le_max(n: U32) -> {U32.is_le(n, 4294967295) == True{} : Bool}:
  match n:
    case U32{w}:
      word_le_ones(32n, w)

def divide_zero(+n: U32) -> {U32.is_le(divide(10n, n), 0) == True{} : Bool}:
  divide_le(10n, n, 4294967295, u32_le_max(n))

def zero_add_bound(+n: Nat, +m: Nat, h: MNat.lt(n, m)) -> MNat.lt(Nat.add(U32.to_nat(0), n), m):
  h

def add_zero(+n: U32) -> {U32.add(0, n) == n : U32}:
  Lemmas.u32_to_nat_inj(U32.add(0, n), n, Lemmas.u32_add_nat(0, n, zero_add_bound(U32.to_nat(n), Lemmas.pow2(32n), Lemmas.u32_to_nat_lt(n))))

def small_quotient(+n: U32, h: {U32.is_lt(n, 10) == True{} : Bool}) -> {quotient(n) == 0 : U32}:
  +hn = Equal.trans(Bool, Nat.is_lt(U32.to_nat(n), 10n), U32.is_lt(n, 10), True{}, Equal.sym(Bool, U32.is_lt(n, 10), Nat.is_lt(U32.to_nat(n), 10n), Lemmas.u32_is_lt_nat(n, 10)), h)
  Lemmas.u32_to_nat_inj(quotient(n), 0,
    Equal.trans(Nat, U32.to_nat(quotient(n)), Nat.div(U32.to_nat(n), 10n), 0n, Lemmas.u32_div_nat(n, 10, {==}), MNat.div_eq_zero_of_le(U32.to_nat(n), 9n, MNat.le_of_lt_succ(U32.to_nat(n), 9n, hn))))

def digit.if(ok: Bool, n: U32) -> Maybe<&2, U32>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{n}

def digit(+acc: U32, +d: U32) -> Maybe<&2, U32>:
  +m = U32.add(U32.mul(acc, 10), d)
  digit.if(Bool.and(U32.is_lt(d, 10), U32.is_eq(quotient(m), acc)), m)

def read(xs: List<&2, U32>, +acc: U32) -> Maybe<&2, U32>:
  match xs:
    case Nil{}:
      Some{acc}
    case Con{d, tail}:
      Maybe.bind(&2, U32, U32, digit(acc, d), n => read(tail, n))


def eq_refl(+n: U32) -> {U32.is_eq(n, n) == True{} : Bool}:
  Equal.trans(Bool, U32.is_eq(n, n), Nat.is_eq(U32.to_nat(n), U32.to_nat(n)), True{}, Lemmas.u32_is_eq_nat(n, n), MNat.is_eq_refl(U32.to_nat(n)))

def digit_step(+acc: U32, +d: U32, +n: U32,
  e: {U32.add(U32.mul(acc, 10), d) == n : U32},
  hd: {U32.is_lt(d, 10) == True{} : Bool},
  hq: {quotient(n) == acc : U32}) -> {digit(acc, d) == Some{n} : Maybe<&2, U32>}:
  %Equal.sym(U32, U32.add(U32.mul(acc, 10), d), n, e) : {digit.if(Bool.and(U32.is_lt(d, 10), U32.is_eq(quotient(_), acc)), _) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(Bool, U32.is_lt(d, 10), True{}, hd) : {digit.if(Bool.and(_, U32.is_eq(quotient(n), acc)), n) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(U32, quotient(n), acc, hq) : {digit.if(Bool.and(True{}, U32.is_eq(_, acc)), n) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(Bool, U32.is_eq(acc, acc), True{}, eq_refl(acc)) : {digit.if(Bool.and(True{}, _), n) == Some{n} : Maybe<&2, U32>}
  {==}

def digit_zero(+n: U32, +h: {U32.is_lt(n, 10) == True{} : Bool}) -> {digit(0, n) == Some{n} : Maybe<&2, U32>}:
  digit_step(0, n, n, add_zero(n), h, small_quotient(n, h))

def digit_rebuild.pair(+n: U32,
  p: {Nat.add(Nat.mul(U32.to_nat(quotient(n)), 10n), U32.to_nat(U32.mod(n, 10))) == U32.to_nat(n) : Nat} & MNat.lt(U32.to_nat(U32.mod(n, 10)), 10n)) ->
  {digit(quotient(n), U32.mod(n, 10)) == Some{n} : Maybe<&2, U32>}:
  (e, hr) = p
  digit_step(quotient(n), U32.mod(n, 10), n, Lemmas.u32_div_mul_add_mod(n, 10, {==}),
    Equal.trans(Bool, U32.is_lt(U32.mod(n, 10), 10), Nat.is_lt(U32.to_nat(U32.mod(n, 10)), 10n), True{}, Lemmas.u32_is_lt_nat(U32.mod(n, 10), 10), hr), {==})

def digit_rebuild(+n: U32) -> {digit(quotient(n), U32.mod(n, 10)) == Some{n} : Maybe<&2, U32>}:
  digit_rebuild.pair(n, Lemmas.u32_divmod_nat(n, 10, {==}))

def text(f: Nat, +n: U32, +tail: List<&2, U32>) -> List<&2, U32>:
  match f:
    case 0n:
      tail
    case 1n+p:
      text(p, quotient(n), Con{U32.mod(n, 10), tail})

def read_cons(+d: U32, +tail: List<&2, U32>, +acc: U32, +n: U32, e: {digit(acc, d) == Some{n} : Maybe<&2, U32>}) -> {read(Con{d, tail}, acc) == read(tail, n) : Maybe<&2, U32>}:
  %Equal.sym(Maybe<&2, U32>, digit(acc, d), Some{n}, e) : {Maybe.bind(&2, U32, U32, _, x => read(tail, x)) == read(tail, n) : Maybe<&2, U32>}
  {==}


def text_roundtrip(+f: Nat, +n: U32, +tail: List<&2, U32>, h: {divide(f, n) == 0 : U32}) -> {read(text(f, n, tail), 0) == read(tail, n) : Maybe<&2, U32>}:
  match f:
    case 0n:
      %Equal.sym(U32, n, 0, h) : {read(text(0n, _, tail), 0) == read(tail, _) : Maybe<&2, U32>}
      {==}
    case 1n+p:
      Equal.trans(Maybe<&2, U32>, read(text(p, quotient(n), Con{U32.mod(n, 10), tail}), 0), read(Con{U32.mod(n, 10), tail}, quotient(n)), read(tail, n), text_roundtrip(p, quotient(n), Con{U32.mod(n, 10), tail}, h), read_cons(U32.mod(n, 10), tail, quotient(n), n, digit_rebuild(n)))

def zero_of_le(+n: U32, h: {U32.is_le(n, 0) == True{} : Bool}) -> {n == 0 : U32}:
  Lemmas.u32_to_nat_inj(n, 0, MNat.le_zero_eq(U32.to_nat(n),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(n), 0n), U32.is_le(n, 0), True{}, Equal.sym(Bool, U32.is_le(n, 0), Nat.is_le(U32.to_nat(n), 0n), Lemmas.u32_is_le_nat(n, 0)), h)))

def roundtrip(+n: U32) -> {read(text(10n, n, Nil{}), 0) == Some{n} : Maybe<&2, U32>}:
  text_roundtrip(10n, n, Nil{}, zero_of_le(divide(10n, n), divide_zero(n)))

def count(f: Nat, +small: Bool, +n: U32, +k: Nat) -> Nat:
  match f:
    case 0n:
      k
    case 1n+p:
      Bool.pick(Nat, small, k, count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k))

def count_shift_step(small: Bool, +p: Nat, +n: U32, +k: Nat,
  ih: {count(p, U32.is_lt(quotient(n), 10), quotient(n), 2n+k) == 1n+count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k) : Nat}) ->
  {count(1n+p, small, n, 1n+k) == 1n+count(1n+p, small, n, k) : Nat}:
  match small:
    case True{}:
      {==}
    case False{}:
      ih

def count_shift(+f: Nat, +small: Bool, +n: U32, +k: Nat) -> {count(f, small, n, 1n+k) == 1n+count(f, small, n, k) : Nat}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      count_shift_step(small, p, n, k, count_shift(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k))

def width_count_step(small: Bool, +p: Nat, +n: U32, +k: Nat,
  ih: {Bytes.u32.width(p, U32.is_lt(quotient(n), 10), quotient(n), U32.from_nat(1n+k)) == U32.from_nat(count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k)) : U32}) ->
  {Bytes.u32.width(1n+p, small, n, U32.from_nat(k)) == U32.from_nat(count(1n+p, small, n, k)) : U32}:
  match small:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(U32, U32.add(U32.from_nat(k), 1), U32.inc(U32.from_nat(k)), Lemmas.u32_add_one(U32.from_nat(k))) :
        {Bytes.u32.width(p, U32.is_lt(quotient(n), 10), quotient(n), _) == U32.from_nat(count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k)) : U32}
      ih

def width_count(+f: Nat, +small: Bool, +n: U32, +k: Nat) -> {Bytes.u32.width(f, small, n, U32.from_nat(k)) == U32.from_nat(count(f, small, n, k)) : U32}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      width_count_step(small, p, n, k, width_count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k))

def count_correct_step(small: Bool, +p: Nat, +n: U32, +es: {small == U32.is_lt(n, 10) : Bool},
  ih: {divide(count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n), quotient(n)) == 0 : U32}) ->
  {divide(count(1n+p, U32.is_lt(n, 10), n, 1n), n) == 0 : U32}:
  match small:
    case True{}:
      %es : {divide(count(1n+p, _, n, 1n), n) == 0 : U32}
      small_quotient(n, Equal.sym(Bool, True{}, U32.is_lt(n, 10), es))
    case False{}:
      %es : {divide(count(1n+p, _, n, 1n), n) == 0 : U32}
      %Equal.sym(Nat, count(p, U32.is_lt(quotient(n), 10), quotient(n), 2n), 1n+count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n), count_shift(p, U32.is_lt(quotient(n), 10), quotient(n), 1n)) :
        {divide(_, n) == 0 : U32}
      ih

def count_correct(+f: Nat, +n: U32, h: {divide(f, n) == 0 : U32}) -> {divide(count(f, U32.is_lt(n, 10), n, 1n), n) == 0 : U32}:
  match f:
    case 0n:
      %Equal.sym(U32, n, 0, h) : {divide(count(0n, U32.is_lt(_, 10), _, 1n), _) == 0 : U32}
      {==}
    case 1n+p:
      count_correct_step(U32.is_lt(n, 10), p, n, {==}, count_correct(p, quotient(n), h))

def count_bound_step(small: Bool, +p: Nat, +n: U32, +k: Nat,
  ih: MNat.le(count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k), Nat.add(1n+k, p))) ->
  MNat.le(count(1n+p, small, n, k), Nat.add(k, 1n+p)):
  match small:
    case True{}:
      MNat.le_add_right(k, 1n+p)
    case False{}:
      %Equal.sym(Nat, Nat.add(k, 1n+p), 1n+Nat.add(k, p), MNat.add_succ(k, p)) :
        MNat.le(count(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k), _)
      ih

def count_bound(+f: Nat, +small: Bool, +n: U32, +k: Nat) -> MNat.le(count(f, small, n, k), Nat.add(k, f)):
  match f:
    case 0n:
      %Equal.sym(Nat, Nat.add(k, 0n), k, MNat.add_zero(k)) : MNat.le(k, _)
      MNat.le_refl(k)
    case 1n+p:
      count_bound_step(small, p, n, k, count_bound(p, U32.is_lt(quotient(n), 10), quotient(n), 1n+k))

def eleven_bound(+m: Nat, h: MNat.lt(U32.to_nat(11), m)) -> MNat.lt(11n, m):
  h

def width_value(+n: U32) -> {U32.to_nat(Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1)) == count(10n, U32.is_lt(n, 10), n, 1n) : Nat}:
  +k = count(10n, U32.is_lt(n, 10), n, 1n)
  Equal.trans(Nat, U32.to_nat(Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1)), U32.to_nat(U32.from_nat(k)), k,
    Equal.cong(U32, Nat, w => U32.to_nat(w), Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1), U32.from_nat(k), width_count(10n, U32.is_lt(n, 10), n, 1n)),
    Lemmas.u32_to_from_nat(k, MNat.lt_of_le_of_lt(k, 11n, Lemmas.pow2(32n), count_bound(10n, U32.is_lt(n, 10), n, 1n), eleven_bound(Lemmas.pow2(32n), Lemmas.u32_to_nat_lt(11)))))

def width_correct(+n: U32) -> {divide(U32.to_nat(Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1)), n) == 0 : U32}:
  %Equal.sym(Nat, U32.to_nat(Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1)), count(10n, U32.is_lt(n, 10), n, 1n), width_value(n)) : {divide(_, n) == 0 : U32}
  count_correct(10n, n, zero_of_le(divide(10n, n), divide_zero(n)))

def width_roundtrip(+n: U32) -> {read(text(U32.to_nat(Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1)), n, Nil{}), 0) == Some{n} : Maybe<&2, U32>}:
  text_roundtrip(U32.to_nat(Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1)), n, Nil{}, width_correct(n))

def text_append(+f: Nat, +n: U32, +left: List<&2, U32>, +right: List<&2, U32>) ->
  {text(f, n, List.append(&2, U32, left, right)) == List.append(&2, U32, text(f, n, left), right) : List<&2, U32>}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      text_append(p, quotient(n), Con{U32.mod(n, 10), left}, right)

def text_tail(+f: Nat, +n: U32, +tail: List<&2, U32>) ->
  {text(f, n, tail) == List.append(&2, U32, text(f, n, Nil{}), tail) : List<&2, U32>}:
  text_append(f, n, Nil{}, tail)

def text_snoc(+p: Nat, +n: U32) ->
  {text(1n+p, n, Nil{}) == List.append(&2, U32, text(p, quotient(n), Nil{}), Con{U32.mod(n, 10), Nil{}}) : List<&2, U32>}:
  text_tail(p, quotient(n), Con{U32.mod(n, 10), Nil{}})
