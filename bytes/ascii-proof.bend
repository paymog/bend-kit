# Exact ASCII digit boundaries for packed decimal parsing.
import Base
import ./bytes.bend as Bytes
import ./decimal-proof.bend as Decimal
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat

def ascii(+d: U32) -> U32:
  U32.add(48, d)

def Facts(+d: U32) -> Type:
  {Bytes.b8(ascii(d)) == ascii(d) : U32} &
  ({U32.sub(ascii(d), 48) == d : U32} &
  ({Bytes.in(48, ascii(d), 57) == True{} : Bool} &
   {U32.is_lt(ascii(d), 256) == True{} : Bool}))

# Ten natural digit cases, not enumeration of U32 bit patterns.
def facts_nat(+k: Nat, +d: U32, e: {U32.to_nat(d) == k : Nat},
  h: MNat.lt(k, 10n)) -> Facts(d):
  match k:
    case 0n:
      %Equal.sym(U32, d, 0, Lemmas.u32_to_nat_inj(d, 0, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 1n:
      %Equal.sym(U32, d, 1, Lemmas.u32_to_nat_inj(d, 1, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 2n:
      %Equal.sym(U32, d, 2, Lemmas.u32_to_nat_inj(d, 2, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 3n:
      %Equal.sym(U32, d, 3, Lemmas.u32_to_nat_inj(d, 3, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 4n:
      %Equal.sym(U32, d, 4, Lemmas.u32_to_nat_inj(d, 4, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 5n:
      %Equal.sym(U32, d, 5, Lemmas.u32_to_nat_inj(d, 5, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 6n:
      %Equal.sym(U32, d, 6, Lemmas.u32_to_nat_inj(d, 6, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 7n:
      %Equal.sym(U32, d, 7, Lemmas.u32_to_nat_inj(d, 7, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 8n:
      %Equal.sym(U32, d, 8, Lemmas.u32_to_nat_inj(d, 8, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 9n:
      %Equal.sym(U32, d, 9, Lemmas.u32_to_nat_inj(d, 9, e)) : Facts(_)
      ({==}, ({==}, ({==}, {==})))
    case 10n+p:
      Empty.absurd(Facts(d), MNat.lt_zero(p)(h))

def digit_facts(+d: U32, h: {U32.is_lt(d, 10) == True{} : Bool}) -> Facts(d):
  facts_nat(U32.to_nat(d), d, {==},
    Equal.trans(Bool, Nat.is_lt(U32.to_nat(d), 10n), U32.is_lt(d, 10), True{},
      Equal.sym(Bool, U32.is_lt(d, 10), Nat.is_lt(U32.to_nat(d), 10n),
        Lemmas.u32_is_lt_nat(d, 10)), h))

def b8_ascii.pair(+d: U32, p: Facts(d)) -> {
  Bytes.b8(ascii(d)) == ascii(d) : U32}:
  (hb, rest) = p
  hb

def sub_ascii.pair(+d: U32, p: Facts(d)) -> {
  U32.sub(ascii(d), 48) == d : U32}:
  (hb, rest) = p
  (hs, tail) = rest
  hs

def in_ascii.pair(+d: U32, p: Facts(d)) -> {
  Bytes.in(48, ascii(d), 57) == True{} : Bool}:
  (hb, rest) = p
  (hs, tail) = rest
  (hi, hl) = tail
  hi

def ascii_lt.pair(+d: U32, p: Facts(d)) -> {
  U32.is_lt(ascii(d), 256) == True{} : Bool}:
  (hb, rest) = p
  (hs, tail) = rest
  (hi, hl) = tail
  hl

def b8_ascii(+d: U32, h: {U32.is_lt(d, 10) == True{} : Bool}) -> {
  Bytes.b8(ascii(d)) == ascii(d) : U32}:
  b8_ascii.pair(d, digit_facts(d, h))

def sub_ascii(+d: U32, h: {U32.is_lt(d, 10) == True{} : Bool}) -> {
  U32.sub(ascii(d), 48) == d : U32}:
  sub_ascii.pair(d, digit_facts(d, h))

def in_ascii(+d: U32, h: {U32.is_lt(d, 10) == True{} : Bool}) -> {
  Bytes.in(48, ascii(d), 57) == True{} : Bool}:
  in_ascii.pair(d, digit_facts(d, h))

def ascii_lt(+d: U32, h: {U32.is_lt(d, 10) == True{} : Bool}) -> {
  U32.is_lt(ascii(d), 256) == True{} : Bool}:
  ascii_lt.pair(d, digit_facts(d, h))

def value(+acc: U32, +d: U32) -> U32:
  U32.add(U32.mul(acc, 10), U32.sub(ascii(d), 48))

def guard(+acc: U32, +d: U32) -> Bool:
  Bool.and(Bytes.in(48, ascii(d), 57), U32.is_eq(U32.div(value(acc, d), 10), acc))

def step_value(+acc: U32, +d: U32, +n: U32,
  hd: {U32.is_lt(d, 10) == True{} : Bool},
  e: {U32.add(U32.mul(acc, 10), d) == n : U32}) -> {value(acc, d) == n : U32}:
  Equal.trans(U32, value(acc, d), U32.add(U32.mul(acc, 10), d), n,
    Equal.cong(U32, U32, x => U32.add(U32.mul(acc, 10), x),
      U32.sub(ascii(d), 48), d, sub_ascii(d, hd)), e)

def step_guard(+acc: U32, +d: U32, +n: U32,
  +hd: {U32.is_lt(d, 10) == True{} : Bool},
  e: {U32.add(U32.mul(acc, 10), d) == n : U32},
  hq: {Decimal.quotient(n) == acc : U32}) -> {guard(acc, d) == True{} : Bool}:
  %Equal.sym(U32, value(acc, d), n, step_value(acc, d, n, hd, e)) : {
    Bool.and(Bytes.in(48, ascii(d), 57), U32.is_eq(Decimal.quotient(_), acc)) == True{} : Bool}
  %Equal.sym(Bool, Bytes.in(48, ascii(d), 57), True{}, in_ascii(d, hd)) : {
    Bool.and(_, U32.is_eq(Decimal.quotient(n), acc)) == True{} : Bool}
  %Equal.sym(U32, Decimal.quotient(n), acc, hq) : {
    Bool.and(True{}, U32.is_eq(_, acc)) == True{} : Bool}
  Decimal.eq_refl(acc)

def step(+acc: U32, +d: U32, +n: U32,
  +hd: {U32.is_lt(d, 10) == True{} : Bool},
  +e: {U32.add(U32.mul(acc, 10), d) == n : U32},
  hq: {Decimal.quotient(n) == acc : U32}) -> {value(acc, d) == n : U32} & {guard(acc, d) == True{} : Bool}:
  (step_value(acc, d, n, hd, e), step_guard(acc, d, n, hd, e, hq))

# Decimal.read stores raw digits; this bridge follows the actual ASCII parser.
def Good(xs: List<&2, U32>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case Con{d, tail}:
      {U32.is_lt(d, 10) == True{} : Bool} & Good(tail)

def ascii_list(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{d, tail}:
      Con{ascii(d), ascii_list(tail)}

def read_ascii(xs: List<&2, U32>, +acc: U32, +ok: Bool) -> Maybe<&2, U32>:
  match xs:
    case Nil{}:
      Bool.pick(Maybe<&2, U32>, ok, Some{acc}, None{})
    case Con{+v, tail}:
      +m = U32.add(U32.mul(acc, 10), U32.sub(v, 48))
      read_ascii(tail, m, Bool.and(ok,
        Bool.and(Bytes.in(48, v, 57), U32.is_eq(U32.div(m, 10), acc))))

def read_false(xs: List<&2, U32>, +acc: U32) -> {
  read_ascii(xs, acc, False{}) == None{} : Maybe<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case Con{+v, tail}:
      read_false(tail, U32.add(U32.mul(acc, 10), U32.sub(v, 48)))

def raw_value(+acc: U32, +d: U32) -> U32:
  U32.add(U32.mul(acc, 10), d)

def raw_guard(+acc: U32, +d: U32) -> Bool:
  Bool.and(U32.is_lt(d, 10), U32.is_eq(Decimal.quotient(raw_value(acc, d)), acc))

def guard_raw(+acc: U32, +d: U32, +hd: {U32.is_lt(d, 10) == True{} : Bool}) -> {
  guard(acc, d) == raw_guard(acc, d) : Bool}:
  %Equal.sym(U32, value(acc, d), raw_value(acc, d),
    step_value(acc, d, raw_value(acc, d), hd, {==})) : {
    Bool.and(Bytes.in(48, ascii(d), 57), U32.is_eq(Decimal.quotient(_), acc)) == raw_guard(acc, d) : Bool}
  %Equal.sym(Bool, Bytes.in(48, ascii(d), 57), True{}, in_ascii(d, hd)) : {
    Bool.and(_, U32.is_eq(Decimal.quotient(raw_value(acc, d)), acc)) == raw_guard(acc, d) : Bool}
  %Equal.sym(Bool, U32.is_lt(d, 10), True{}, hd) : {
    Bool.and(True{}, U32.is_eq(Decimal.quotient(raw_value(acc, d)), acc)) ==
    Bool.and(_, U32.is_eq(Decimal.quotient(raw_value(acc, d)), acc)) : Bool}
  {==}

def read_cons_bridge(+d: U32, +tail: List<&2, U32>, +acc: U32,
  +hd: {U32.is_lt(d, 10) == True{} : Bool}) -> {
  read_ascii(ascii_list(Con{d, tail}), acc, True{}) ==
  read_ascii(ascii_list(tail), raw_value(acc, d), raw_guard(acc, d)) : Maybe<&2, U32>}:
  %Equal.sym(U32, value(acc, d), raw_value(acc, d),
    step_value(acc, d, raw_value(acc, d), hd, {==})) : {
    read_ascii(ascii_list(tail), _, guard(acc, d)) ==
    read_ascii(ascii_list(tail), raw_value(acc, d), raw_guard(acc, d)) : Maybe<&2, U32>}
  %Equal.sym(Bool, guard(acc, d), raw_guard(acc, d), guard_raw(acc, d, hd)) : {
    read_ascii(ascii_list(tail), raw_value(acc, d), _) ==
    read_ascii(ascii_list(tail), raw_value(acc, d), raw_guard(acc, d)) : Maybe<&2, U32>}
  {==}

def read_branch(+ok: Bool, +xs: List<&2, U32>, +acc: U32,
  ih: {read_ascii(ascii_list(xs), acc, True{}) == Decimal.read(xs, acc) : Maybe<&2, U32>}) -> {
  read_ascii(ascii_list(xs), acc, ok) ==
  Maybe.bind(&2, U32, U32, Decimal.digit.if(ok, acc), x => Decimal.read(xs, x)) : Maybe<&2, U32>}:
  match ok:
    case False{}:
      read_false(ascii_list(xs), acc)
    case True{}:
      ih

def read_good(+xs: List<&2, U32>, +acc: U32, h: Good(xs)) -> {
  read_ascii(ascii_list(xs), acc, True{}) == Decimal.read(xs, acc) : Maybe<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case Con{+d, +tail}:
      (hd, ht) = h
      Equal.trans(Maybe<&2, U32>, read_ascii(ascii_list(Con{d, tail}), acc, True{}),
        read_ascii(ascii_list(tail), raw_value(acc, d), raw_guard(acc, d)),
        Decimal.read(Con{d, tail}, acc), read_cons_bridge(d, tail, acc, hd),
        read_branch(raw_guard(acc, d), tail, raw_value(acc, d),
          read_good(tail, raw_value(acc, d), ht)))

def remainder_lt.pair(+n: U32, p:
  {Nat.add(Nat.mul(U32.to_nat(Decimal.quotient(n)), 10n), U32.to_nat(U32.mod(n, 10))) == U32.to_nat(n) : Nat} &
  MNat.lt(U32.to_nat(U32.mod(n, 10)), 10n)) -> {U32.is_lt(U32.mod(n, 10), 10) == True{} : Bool}:
  (e, hr) = p
  Equal.trans(Bool, U32.is_lt(U32.mod(n, 10), 10),
    Nat.is_lt(U32.to_nat(U32.mod(n, 10)), 10n), True{},
    Lemmas.u32_is_lt_nat(U32.mod(n, 10), 10), hr)

def remainder_lt(+n: U32) -> {U32.is_lt(U32.mod(n, 10), 10) == True{} : Bool}:
  remainder_lt.pair(n, Lemmas.u32_divmod_nat(n, 10, {==}))

def text_good(f: Nat, +n: U32, +tail: List<&2, U32>, ht: Good(tail)) -> Good(Decimal.text(f, n, tail)):
  match f:
    case 0n:
      ht
    case 1n+p:
      text_good(p, Decimal.quotient(n), Con{U32.mod(n, 10), tail}, (remainder_lt(n), ht))

def ascii_append(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {
  ascii_list(List.append(&2, U32, xs, ys)) ==
  List.append(&2, U32, ascii_list(xs), ascii_list(ys)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case Con{+d, +tail}:
      Equal.cong(List<&2, U32>, List<&2, U32>, zs => Con{ascii(d), zs},
        ascii_list(List.append(&2, U32, tail, ys)),
        List.append(&2, U32, ascii_list(tail), ascii_list(ys)),
        ascii_append(tail, ys))
