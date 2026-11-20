# Structural bridges from the runtime decimal loops to packed-word list memory.
import Base
import ./bytes.bend as Bytes
import ./array-proof.bend as ArrayModel
import ./packed-proof.bend as Packed
import ./ascii-proof.bend as Ascii
import ./decimal-proof.bend as Decimal
import ../lemmas/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool

def digits(f: Nat, +l: List<&2, U32>, +i: U32, +n: U32) -> List<&2, U32>:
  match f:
    case 0n:
      l
    case 1n+p:
      digits(p, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), U32.sub(i, 1), U32.div(n, 10))

def Pred(+i: U32) -> Type:
  MNat.lt(U32.to_nat(U32.sub(i, 1)), U32.to_nat(i))
  & {1n+U32.to_nat(U32.sub(i, 1)) == U32.to_nat(i) : Nat}

def predecessor_at(n: Nat, +i: U32, e: {n == U32.to_nat(i) : Nat}, h: MNat.lt(n, 16n), pos: MNat.le(1n, n)) -> Pred(i):
  match n:
    case 0n:
      Empty.absurd(Pred(i), MBool.false_ne_true()(pos))
    case 1n:
      %Lemmas.u32_to_nat_inj(1, i, e) : Pred(_)
      ({==}, {==})
    case 2n:
      %Lemmas.u32_to_nat_inj(2, i, e) : Pred(_)
      ({==}, {==})
    case 3n:
      %Lemmas.u32_to_nat_inj(3, i, e) : Pred(_)
      ({==}, {==})
    case 4n:
      %Lemmas.u32_to_nat_inj(4, i, e) : Pred(_)
      ({==}, {==})
    case 5n:
      %Lemmas.u32_to_nat_inj(5, i, e) : Pred(_)
      ({==}, {==})
    case 6n:
      %Lemmas.u32_to_nat_inj(6, i, e) : Pred(_)
      ({==}, {==})
    case 7n:
      %Lemmas.u32_to_nat_inj(7, i, e) : Pred(_)
      ({==}, {==})
    case 8n:
      %Lemmas.u32_to_nat_inj(8, i, e) : Pred(_)
      ({==}, {==})
    case 9n:
      %Lemmas.u32_to_nat_inj(9, i, e) : Pred(_)
      ({==}, {==})
    case 10n:
      %Lemmas.u32_to_nat_inj(10, i, e) : Pred(_)
      ({==}, {==})
    case 11n:
      %Lemmas.u32_to_nat_inj(11, i, e) : Pred(_)
      ({==}, {==})
    case 12n:
      %Lemmas.u32_to_nat_inj(12, i, e) : Pred(_)
      ({==}, {==})
    case 13n:
      %Lemmas.u32_to_nat_inj(13, i, e) : Pred(_)
      ({==}, {==})
    case 14n:
      %Lemmas.u32_to_nat_inj(14, i, e) : Pred(_)
      ({==}, {==})
    case 15n:
      %Lemmas.u32_to_nat_inj(15, i, e) : Pred(_)
      ({==}, {==})
    case 16n+p:
      Empty.absurd(Pred(i), MNat.lt_zero(p)(h))

def pred_lt.of(-i: U32, r: Pred(i)) -> MNat.lt(U32.to_nat(U32.sub(i, 1)), U32.to_nat(i)):
  (hl, he) = r
  hl

def pred_succ.of(-i: U32, r: Pred(i)) -> {1n+U32.to_nat(U32.sub(i, 1)) == U32.to_nat(i) : Nat}:
  (hl, he) = r
  he

def positive_of_two(+p: Nat, +n: Nat, h: MNat.le(2n+p, 1n+n)) -> MNat.le(1n, n):
  match n:
    case 0n:
      Empty.absurd(MNat.le(1n, 0n), MBool.false_ne_true()(h))
    case 1n+q:
      MNat.zero_le(q)

def digits_model(f: Nat, +d: Nat, +l: List<&2, U32>, +i: U32, +n: U32, +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(i), Packed.capacity(d)), +hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l)), +hf: MNat.le(f, 1n+U32.to_nat(i))) -> {Bytes.u32.digits(f, ArrayModel.build(d, l), i, n) == ArrayModel.build(d, digits(f, l, i, n)) : Array<U32>}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      match p:
        case 0n:
          %Equal.sym(Array<U32>, Bytes.poke(ArrayModel.build(d, l), i, U32.add(48, U32.mod(n, 10))), ArrayModel.build(d, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10)))), Packed.poke_model(d, l, i, U32.add(48, U32.mod(n, 10)), hd, hi, hl)) : {Bytes.u32.digits(0n, _, U32.sub(i, 1), U32.div(n, 10)) == ArrayModel.build(d, digits(1n, l, i, n)) : Array<U32>}
          {==}
        case 1n++q:
          %Equal.sym(Array<U32>, Bytes.poke(ArrayModel.build(d, l), i, U32.add(48, U32.mod(n, 10))), ArrayModel.build(d, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10)))), Packed.poke_model(d, l, i, U32.add(48, U32.mod(n, 10)), hd, hi, hl)) : {Bytes.u32.digits(1n+q, _, U32.sub(i, 1), U32.div(n, 10)) == ArrayModel.build(d, digits(2n+q, l, i, n)) : Array<U32>}
          +pos = positive_of_two(q, U32.to_nat(i), hf)
          +h16 = Packed.byte_lt16(d, i, hd, hi)
          digits_model(1n+q, d, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), U32.sub(i, 1), U32.div(n, 10), hd,
            MNat.lt_trans(U32.to_nat(U32.sub(i, 1)), U32.to_nat(i), Packed.capacity(d), pred_lt.of(i, predecessor_at(U32.to_nat(i), i, {==}, h16, pos)), hi),
            (%Equal.sym(Nat, ArrayModel.len(Packed.write_at(l, i, U32.add(48, U32.mod(n, 10)))), ArrayModel.len(l), Packed.write_length(l, i, U32.add(48, U32.mod(n, 10)))) : MNat.le(Lemmas.pow2(d), _)
             hl),
            (%Equal.sym(Nat, 1n+U32.to_nat(U32.sub(i, 1)), U32.to_nat(i), pred_succ.of(i, predecessor_at(U32.to_nat(i), i, {==}, h16, pos))) : MNat.le(1n+q, _)
             hf))

def read(f: Nat, +l: List<&2, U32>, +i: U32, +acc: U32, +ok: Bool) -> Maybe<&2, U32>:
  match f:
    case 0n:
      Bool.pick(Maybe<&2, U32>, ok, Some{acc}, None{})
    case 1n+p:
      +v = Packed.byte_at(l, i)
      +m = U32.add(U32.mul(acc, 10), U32.sub(v, 48))
      read(p, l, U32.add(i, 1), m, Bool.and(ok, Bool.and(Bytes.in(48, v, 57), U32.is_eq(U32.div(m, 10), acc))))

# The terminal loop ignores the speculative peek, including a wrapped final address.
def read_zero(r: Array<U32> & U32, -i: U32, +acc: U32, +ok: Bool) -> {Bytes.u32.read.go(0n, r, i, acc, ok) == Bool.pick(Maybe<&2, U32>, ok, Some{acc}, None{}) : Maybe<&2, U32>}:
  (a, v) = r
  {==}

def successor_at(n: Nat, +i: U32, e: {n == U32.to_nat(i) : Nat}, h: MNat.lt(n, 16n)) -> {1n+U32.to_nat(i) == U32.to_nat(U32.add(i, 1)) : Nat}:
  match n:
    case 0n:
      %Lemmas.u32_to_nat_inj(0, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 1n:
      %Lemmas.u32_to_nat_inj(1, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 2n:
      %Lemmas.u32_to_nat_inj(2, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 3n:
      %Lemmas.u32_to_nat_inj(3, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 4n:
      %Lemmas.u32_to_nat_inj(4, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 5n:
      %Lemmas.u32_to_nat_inj(5, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 6n:
      %Lemmas.u32_to_nat_inj(6, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 7n:
      %Lemmas.u32_to_nat_inj(7, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 8n:
      %Lemmas.u32_to_nat_inj(8, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 9n:
      %Lemmas.u32_to_nat_inj(9, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 10n:
      %Lemmas.u32_to_nat_inj(10, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 11n:
      %Lemmas.u32_to_nat_inj(11, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 12n:
      %Lemmas.u32_to_nat_inj(12, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 13n:
      %Lemmas.u32_to_nat_inj(13, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 14n:
      %Lemmas.u32_to_nat_inj(14, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 15n:
      %Lemmas.u32_to_nat_inj(15, i, e) : {1n+U32.to_nat(_) == U32.to_nat(U32.add(_, 1)) : Nat}
      {==}
    case 16n+p:
      Empty.absurd({1n+U32.to_nat(i) == U32.to_nat(U32.add(i, 1)) : Nat}, MNat.lt_zero(p)(h))

def add_step(+n: Nat, -p: Nat) -> {Nat.add(n, 1n+p) == Nat.add(1n+n, p) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++q:
      %add_step(q, p) : {1n+Nat.add(q, 1n+p) == 1n+_ : Nat}
      {==}

def head_bound(+n: Nat, +p: Nat, +c: Nat, h: MNat.le(Nat.add(n, 1n+p), c)) -> MNat.lt(n, c):
  match n:
    case 0n:
      match c:
        case 0n:
          Empty.absurd(MNat.lt(0n, 0n), MBool.false_ne_true()(h))
        case 1n+q:
          {==}
    case 1n++q:
      match c:
        case 0n:
          Empty.absurd(MNat.lt(1n+q, 0n), MBool.false_ne_true()(h))
        case 1n++r:
          head_bound(q, p, r, h)

def read_model(f: Nat, +d: Nat, +l: List<&2, U32>, +i: U32, +acc: U32, +ok: Bool, +hd: MNat.lt(d, 3n), +hf: MNat.le(Nat.add(U32.to_nat(i), f), Packed.capacity(d))) -> {Bytes.u32.read.go(f, Bytes.peek(ArrayModel.build(d, l), i), i, acc, ok) == read(f, l, i, acc, ok) : Maybe<&2, U32>}:
  match f:
    case 0n:
      read_zero(Bytes.peek(ArrayModel.build(d, l), i), i, acc, ok)
    case 1n++p:
      +hi = head_bound(U32.to_nat(i), p, Packed.capacity(d), hf)
      %Equal.sym(Array<U32> & U32, Bytes.peek(ArrayModel.build(d, l), i), (ArrayModel.build(d, l), Packed.byte_at(l, i)), Packed.peek_model(d, l, i, hd, hi)) : {Bytes.u32.read.go(1n+p, _, i, acc, ok) == read(1n+p, l, i, acc, ok) : Maybe<&2, U32>}
      read_model(p, d, l, U32.add(i, 1), U32.add(U32.mul(acc, 10), U32.sub(Packed.byte_at(l, i), 48)), Bool.and(ok, Bool.and(Bytes.in(48, Packed.byte_at(l, i), 57), U32.is_eq(U32.div(U32.add(U32.mul(acc, 10), U32.sub(Packed.byte_at(l, i), 48)), 10), acc))), hd,
        (%successor_at(U32.to_nat(i), i, {==}, Packed.byte_lt16(d, i, hd, hi)) : MNat.le(Nat.add(_, p), Packed.capacity(d))
         %add_step(U32.to_nat(i), p) : MNat.le(_, Packed.capacity(d))
         hf))

def fetch(f: Nat, +l: List<&2, U32>, +i: U32) -> List<&2, U32>:
  match f:
    case 0n:
      Nil{}
    case 1n+p:
      Con{Packed.byte_at(l, i), fetch(p, l, U32.add(i, 1))}


def advance(f: Nat, +i: U32) -> U32:
  match f:
    case 0n:
      i
    case 1n+p:
      advance(p, U32.add(i, 1))

def fetch_snoc(f: Nat, +l: List<&2, U32>, +i: U32) -> {fetch(1n+f, l, i) == List.append(&2, U32, fetch(f, l, i), [Packed.byte_at(l, advance(f, i))]) : List<&2, U32>}:
  match f:
    case 0n:
      {==}
    case 1n++p:
      %fetch_snoc(p, l, U32.add(i, 1)) : {Con{Packed.byte_at(l, i), fetch(1n+p, l, U32.add(i, 1))} == Con{Packed.byte_at(l, i), _} : List<&2, U32>}
      {==}

def digits_length(f: Nat, +l: List<&2, U32>, +i: U32, +n: U32) -> {ArrayModel.len(digits(f, l, i, n)) == ArrayModel.len(l) : Nat}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      Equal.trans(Nat, ArrayModel.len(digits(p, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), U32.sub(i, 1), U32.div(n, 10))), ArrayModel.len(Packed.write_at(l, i, U32.add(48, U32.mod(n, 10)))), ArrayModel.len(l), digits_length(p, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), U32.sub(i, 1), U32.div(n, 10)), Packed.write_length(l, i, U32.add(48, U32.mod(n, 10))))

def lt_self_false(n: Nat, h: MNat.lt(n, n)) -> Empty:
  match n:
    case 0n:
      MBool.false_ne_true()(h)
    case 1n+p:
      lt_self_false(p, h)

def address_ne(+i: U32, +j: U32, h: MNat.lt(U32.to_nat(i), U32.to_nat(j)), e: {i == j : U32}) -> Empty:
  lt_self_false(U32.to_nat(i),
    %Equal.sym(U32, i, j, e) : MNat.lt(U32.to_nat(i), U32.to_nat(_))
    h)

def digits_other.step(+f: Nat, +l: List<&2, U32>, +i: U32, +n: U32, +j: U32,
  hi: MNat.lt(U32.to_nat(i), 16n), hj: MNat.lt(U32.to_nat(j), 16n),
  hs: MNat.lt(Packed.slot(i), ArrayModel.len(l)), habove: MNat.lt(U32.to_nat(i), U32.to_nat(j)),
  ih: {Packed.byte_at(digits(f, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), U32.sub(i, 1), U32.div(n, 10)), j) == Packed.byte_at(Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), j) : U32}) -> {Packed.byte_at(digits(1n+f, l, i, n), j) == Packed.byte_at(l, j) : U32}:
  Equal.trans(U32, Packed.byte_at(digits(1n+f, l, i, n), j), Packed.byte_at(Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), j), Packed.byte_at(l, j), ih,
    Packed.byte_write_other(l, i, j, U32.add(48, U32.mod(n, 10)), hi, hj, hs, e => address_ne(i, j, habove, e)))

def digits_other(f: Nat, +d: Nat, +l: List<&2, U32>, +i: U32, +n: U32, +j: U32,
  +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(i), Packed.capacity(d)), +hj: MNat.lt(U32.to_nat(j), 16n),
  +hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l)), +hf: MNat.le(f, 1n+U32.to_nat(i)),
  +habove: MNat.lt(U32.to_nat(i), U32.to_nat(j))) -> {Packed.byte_at(digits(f, l, i, n), j) == Packed.byte_at(l, j) : U32}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      match p:
        case 0n:
          digits_other.step(0n, l, i, n, j, Packed.byte_lt16(d, i, hd, hi), hj, ArrayModel.lt_le_trans(Packed.slot(i), Lemmas.pow2(d), ArrayModel.len(l), Packed.slot_bound(d, i, hd, hi), hl), habove, {==})
        case 1n++q:
          +pos = positive_of_two(q, U32.to_nat(i), hf)
          +h16 = Packed.byte_lt16(d, i, hd, hi)
          +hp = pred_lt.of(i, predecessor_at(U32.to_nat(i), i, {==}, h16, pos))
          digits_other.step(1n+q, l, i, n, j, h16, hj, ArrayModel.lt_le_trans(Packed.slot(i), Lemmas.pow2(d), ArrayModel.len(l), Packed.slot_bound(d, i, hd, hi), hl), habove,
            digits_other(1n+q, d, Packed.write_at(l, i, U32.add(48, U32.mod(n, 10))), U32.sub(i, 1), U32.div(n, 10), j, hd,
              MNat.lt_trans(U32.to_nat(U32.sub(i, 1)), U32.to_nat(i), Packed.capacity(d), hp, hi), hj,
              (%Equal.sym(Nat, ArrayModel.len(Packed.write_at(l, i, U32.add(48, U32.mod(n, 10)))), ArrayModel.len(l), Packed.write_length(l, i, U32.add(48, U32.mod(n, 10)))) : MNat.le(Lemmas.pow2(d), _)
               hl),
              (%Equal.sym(Nat, 1n+U32.to_nat(U32.sub(i, 1)), U32.to_nat(i), pred_succ.of(i, predecessor_at(U32.to_nat(i), i, {==}, h16, pos))) : MNat.le(1n+q, _)
               hf),
              MNat.lt_trans(U32.to_nat(U32.sub(i, 1)), U32.to_nat(i), U32.to_nat(j), hp, habove)))

def read_fetch(f: Nat, +l: List<&2, U32>, +i: U32, +acc: U32, +ok: Bool) -> {read(f, l, i, acc, ok) == Ascii.read_ascii(fetch(f, l, i), acc, ok) : Maybe<&2, U32>}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      read_fetch(p, l, U32.add(i, 1), U32.add(U32.mul(acc, 10), U32.sub(Packed.byte_at(l, i), 48)), Bool.and(ok, Bool.and(Bytes.in(48, Packed.byte_at(l, i), 57), U32.is_eq(U32.div(U32.add(U32.mul(acc, 10), U32.sub(Packed.byte_at(l, i), 48)), 10), acc))))

# Only these eleven natural addresses occur in a fixed-count decimal rendering.
def Index(+p: Nat) -> Type:
  {U32.to_nat(U32.from_nat(p)) == p : Nat}
  & ({advance(p, 0) == U32.from_nat(p) : U32}
  & {U32.sub(U32.from_nat(1n+p), 1) == U32.from_nat(p) : U32})

def index(p: Nat, h: MNat.lt(p, 11n)) -> Index(p):
  match p:
    case 0n:
      ({==}, ({==}, {==}))
    case 1n:
      ({==}, ({==}, {==}))
    case 2n:
      ({==}, ({==}, {==}))
    case 3n:
      ({==}, ({==}, {==}))
    case 4n:
      ({==}, ({==}, {==}))
    case 5n:
      ({==}, ({==}, {==}))
    case 6n:
      ({==}, ({==}, {==}))
    case 7n:
      ({==}, ({==}, {==}))
    case 8n:
      ({==}, ({==}, {==}))
    case 9n:
      ({==}, ({==}, {==}))
    case 10n:
      ({==}, ({==}, {==}))
    case 11n+q:
      Empty.absurd(Index(11n+q), MNat.lt_zero(q)(h))

def index_nat.of(-p: Nat, r: Index(p)) -> {U32.to_nat(U32.from_nat(p)) == p : Nat}:
  (hn, rest) = r
  hn

def advance_zero.of(-p: Nat, r: Index(p)) -> {advance(p, 0) == U32.from_nat(p) : U32}:
  (hn, rest) = r
  (ha, hb) = rest
  ha

def back_nat.of(-p: Nat, r: Index(p)) -> {U32.sub(U32.from_nat(1n+p), 1) == U32.from_nat(p) : U32}:
  (hn, rest) = r
  (ha, hb) = rest
  hb

def index_nat(+p: Nat, h: MNat.lt(p, 11n)) -> {U32.to_nat(U32.from_nat(p)) == p : Nat}:
  index_nat.of(p, index(p, h))

def advance_zero(+p: Nat, h: MNat.lt(p, 11n)) -> {advance(p, 0) == U32.from_nat(p) : U32}:
  advance_zero.of(p, index(p, h))

def back_nat(+p: Nat, h: MNat.lt(p, 11n)) -> {U32.sub(U32.from_nat(1n+p), 1) == U32.from_nat(p) : U32}:
  back_nat.of(p, index(p, h))

def end(f: Nat) -> U32:
  match f:
    case 0n:
      0
    case 1n+p:
      U32.from_nat(p)

def le_refl(n: Nat) -> MNat.le(n, n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      le_refl(p)

def le_drop(+a: Nat, +b: Nat, h: MNat.le(1n+a, b)) -> MNat.le(a, b):
  match a:
    case 0n:
      MNat.zero_le(b)
    case 1n++p:
      match b:
        case 0n:
          Empty.absurd(MNat.le(1n+p, 0n), MBool.false_ne_true()(h))
        case 1n++q:
          le_drop(p, q, h)

def smaller_bound(+p: Nat, h: MNat.lt(1n+p, 11n)) -> MNat.lt(p, 11n):
  MNat.lt_trans(p, 1n+p, 11n, MNat.lt_succ_self(p), h)

def end_count(+p: Nat, hp: MNat.lt(p, 11n)) -> MNat.le(p, 1n+U32.to_nat(end(p))):
  match p:
    case 0n:
      {==}
    case 1n++q:
      %Equal.sym(Nat, U32.to_nat(U32.from_nat(q)), q, index_nat(q, smaller_bound(q, hp))) : MNat.le(1n+q, 1n+_)
      le_refl(1n+q)

def end_before(+q: Nat, +hq: MNat.lt(1n+q, 11n)) -> MNat.lt(U32.to_nat(end(1n+q)), U32.to_nat(U32.from_nat(1n+q))):
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(q)), q, index_nat(q, smaller_bound(q, hq))) : MNat.lt(_, U32.to_nat(U32.from_nat(1n+q)))
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(1n+q)), 1n+q, index_nat(1n+q, hq)) : MNat.lt(q, _)
  MNat.lt_succ_self(q)

def digits_sub_end(+p: Nat, +l: List<&2, U32>, +n: U32, hp: MNat.lt(p, 11n)) -> {digits(p, l, U32.sub(U32.from_nat(p), 1), n) == digits(p, l, end(p), n) : List<&2, U32>}:
  match p:
    case 0n:
      {==}
    case 1n++q:
      %Equal.sym(U32, U32.sub(U32.from_nat(1n+q), 1), U32.from_nat(q), back_nat(q, smaller_bound(q, hp))) : {digits(1n+q, l, _, n) == digits(1n+q, l, end(1n+q), n) : List<&2, U32>}
      {==}

def succ_le_lt(+a: Nat, +b: Nat, h: MNat.le(1n+a, b)) -> MNat.lt(a, b):
  match a:
    case 0n:
      match b:
        case 0n:
          Empty.absurd(MNat.lt(0n, 0n), MBool.false_ne_true()(h))
        case 1n+q:
          {==}
    case 1n++p:
      match b:
        case 0n:
          Empty.absurd(MNat.lt(1n+p, 0n), MBool.false_ne_true()(h))
        case 1n++q:
          succ_le_lt(p, q, h)

def last_written_b8(+p: Nat, +d: Nat, +l: List<&2, U32>, +n: U32,
  +hd: MNat.lt(d, 3n), +hp: MNat.lt(p, 11n), +hc: MNat.le(1n+p, Packed.capacity(d)),
  +hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l))) ->
  {Packed.byte_at(digits(1n+p, l, U32.from_nat(p), n), U32.from_nat(p)) == Bytes.b8(Ascii.ascii(U32.mod(n, 10))) : U32}:
  match p:
    case 0n:
      Packed.byte_write_same(l, 0, Ascii.ascii(U32.mod(n, 10)),
        ArrayModel.lt_le_trans(Packed.slot(0), Lemmas.pow2(d), ArrayModel.len(l), Packed.slot_bound(d, 0, hd, head_bound(0n, 0n, Packed.capacity(d), hc)), hl), {==})
    case 1n++q:
      +hi : MNat.lt(U32.to_nat(U32.from_nat(1n+q)), Packed.capacity(d)) = (%Equal.sym(Nat, U32.to_nat(U32.from_nat(1n+q)), 1n+q, index_nat(1n+q, hp)) : MNat.lt(_, Packed.capacity(d))
             succ_le_lt(1n+q, Packed.capacity(d), hc))
      +lw = Packed.write_at(l, U32.from_nat(1n+q), Ascii.ascii(U32.mod(n, 10)))
      Equal.trans(U32, Packed.byte_at(digits(2n+q, l, U32.from_nat(1n+q), n), U32.from_nat(1n+q)), Packed.byte_at(lw, U32.from_nat(1n+q)), Bytes.b8(Ascii.ascii(U32.mod(n, 10))),
        (%Equal.sym(List<&2, U32>, digits(1n+q, lw, U32.sub(U32.from_nat(1n+q), 1), U32.div(n, 10)), digits(1n+q, lw, end(1n+q), U32.div(n, 10)), digits_sub_end(1n+q, lw, U32.div(n, 10), hp)) : {Packed.byte_at(_, U32.from_nat(1n+q)) == Packed.byte_at(lw, U32.from_nat(1n+q)) : U32}
         digits_other(1n+q, d, lw, end(1n+q), U32.div(n, 10), U32.from_nat(1n+q), hd,
           MNat.lt_trans(U32.to_nat(end(1n+q)), U32.to_nat(U32.from_nat(1n+q)), Packed.capacity(d), end_before(q, hp), hi),
           Packed.byte_lt16(d, U32.from_nat(1n+q), hd, hi),
           (%Equal.sym(Nat, ArrayModel.len(lw), ArrayModel.len(l), Packed.write_length(l, U32.from_nat(1n+q), Ascii.ascii(U32.mod(n, 10)))) : MNat.le(Lemmas.pow2(d), _)
            hl), end_count(1n+q, hp), end_before(q, hp))),
        Packed.byte_write_same(l, U32.from_nat(1n+q), Ascii.ascii(U32.mod(n, 10)), ArrayModel.lt_le_trans(Packed.slot(U32.from_nat(1n+q)), Lemmas.pow2(d), ArrayModel.len(l), Packed.slot_bound(d, U32.from_nat(1n+q), hd, hi), hl), Packed.lane_bound(U32.from_nat(1n+q), Packed.byte_lt16(d, U32.from_nat(1n+q), hd, hi))))

def last_written(+p: Nat, +d: Nat, +l: List<&2, U32>, +n: U32,
  hd: MNat.lt(d, 3n), hp: MNat.lt(p, 11n), hc: MNat.le(1n+p, Packed.capacity(d)),
  hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l))) ->
  {Packed.byte_at(digits(1n+p, l, U32.from_nat(p), n), U32.from_nat(p)) == Ascii.ascii(U32.mod(n, 10)) : U32}:
  Equal.trans(U32, Packed.byte_at(digits(1n+p, l, U32.from_nat(p), n), U32.from_nat(p)), Bytes.b8(Ascii.ascii(U32.mod(n, 10))), Ascii.ascii(U32.mod(n, 10)),
    last_written_b8(p, d, l, n, hd, hp, hc, hl), Ascii.b8_ascii(U32.mod(n, 10), Ascii.remainder_lt(n)))

def fetch_digits.join(+p: Nat, +l: List<&2, U32>, +n: U32, hp: MNat.lt(p, 11n),
  ep: {fetch(p, l, 0) == Ascii.ascii_list(Decimal.text(p, U32.div(n, 10), Nil{})) : List<&2, U32>},
  el: {Packed.byte_at(l, U32.from_nat(p)) == Ascii.ascii(U32.mod(n, 10)) : U32}) ->
  {fetch(1n+p, l, 0) == Ascii.ascii_list(Decimal.text(1n+p, n, Nil{})) : List<&2, U32>}:
  %Equal.sym(List<&2, U32>, Decimal.text(1n+p, n, Nil{}), List.append(&2, U32, Decimal.text(p, U32.div(n, 10), Nil{}), [U32.mod(n, 10)]), Decimal.text_snoc(p, n)) : {fetch(1n+p, l, 0) == Ascii.ascii_list(_) : List<&2, U32>}
  %Equal.sym(List<&2, U32>, Ascii.ascii_list(List.append(&2, U32, Decimal.text(p, U32.div(n, 10), Nil{}), [U32.mod(n, 10)])), List.append(&2, U32, Ascii.ascii_list(Decimal.text(p, U32.div(n, 10), Nil{})), [Ascii.ascii(U32.mod(n, 10))]), Ascii.ascii_append(Decimal.text(p, U32.div(n, 10), Nil{}), [U32.mod(n, 10)])) : {fetch(1n+p, l, 0) == _ : List<&2, U32>}
  %ep : {fetch(1n+p, l, 0) == List.append(&2, U32, _, [Ascii.ascii(U32.mod(n, 10))]) : List<&2, U32>}
  %el : {fetch(1n+p, l, 0) == List.append(&2, U32, fetch(p, l, 0), [_]) : List<&2, U32>}
  %advance_zero(p, hp) : {fetch(1n+p, l, 0) == List.append(&2, U32, fetch(p, l, 0), [Packed.byte_at(l, _)]) : List<&2, U32>}
  fetch_snoc(p, l, 0)

def fetch_digits(f: Nat, +d: Nat, +l: List<&2, U32>, +n: U32,
  +hd: MNat.lt(d, 3n), +hf: MNat.lt(f, 12n), +hc: MNat.le(f, Packed.capacity(d)),
  +hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l))) ->
  {fetch(f, digits(f, l, end(f), n), 0) == Ascii.ascii_list(Decimal.text(f, n, Nil{})) : List<&2, U32>}:
  match f:
    case 0n:
      {==}
    case 1n++p:
      +lw = Packed.write_at(l, U32.from_nat(p), Ascii.ascii(U32.mod(n, 10)))
      fetch_digits.join(p, digits(1n+p, l, U32.from_nat(p), n), n, hf,
        Equal.trans(List<&2, U32>, fetch(p, digits(p, lw, U32.sub(U32.from_nat(p), 1), U32.div(n, 10)), 0), fetch(p, digits(p, lw, end(p), U32.div(n, 10)), 0), Ascii.ascii_list(Decimal.text(p, U32.div(n, 10), Nil{})),
          Equal.cong(List<&2, U32>, List<&2, U32>, zs => fetch(p, zs, 0), digits(p, lw, U32.sub(U32.from_nat(p), 1), U32.div(n, 10)), digits(p, lw, end(p), U32.div(n, 10)), digits_sub_end(p, lw, U32.div(n, 10), hf)),
          fetch_digits(p, d, lw, U32.div(n, 10), hd, MNat.lt_trans(p, 11n, 12n, hf, {==}), le_drop(p, Packed.capacity(d), hc),
            (%Equal.sym(Nat, ArrayModel.len(lw), ArrayModel.len(l), Packed.write_length(l, U32.from_nat(p), Ascii.ascii(U32.mod(n, 10)))) : MNat.le(Lemmas.pow2(d), _)
             hl))),
        last_written(p, d, l, n, hd, hf, hc, hl))

def sub_zero(p: Nat) -> {Nat.sub(p, 0n) == p : Nat}:
  match p:
    case 0n:
      {==}
    case 1n+q:
      {==}

def end_from_sub(f: Nat) -> {U32.from_nat(Nat.sub(f, 1n)) == end(f) : U32}:
  match f:
    case 0n:
      {==}
    case 1n++p:
      Equal.cong(Nat, U32, U32.from_nat, Nat.sub(p, 0n), p, sub_zero(p))

def fetch_digits_from_sub(+f: Nat, +d: Nat, +l: List<&2, U32>, +n: U32,
  hd: MNat.lt(d, 3n), hf: MNat.lt(f, 12n), hc: MNat.le(f, Packed.capacity(d)),
  hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l))) ->
  {fetch(f, digits(f, l, U32.from_nat(Nat.sub(f, 1n)), n), 0) == Ascii.ascii_list(Decimal.text(f, n, Nil{})) : List<&2, U32>}:
  %Equal.sym(U32, U32.from_nat(Nat.sub(f, 1n)), end(f), end_from_sub(f)) : {fetch(f, digits(f, l, _, n), 0) == Ascii.ascii_list(Decimal.text(f, n, Nil{})) : List<&2, U32>}
  fetch_digits(f, d, l, n, hd, hf, hc, hl)
