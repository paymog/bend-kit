import Base
import ./bytes.bend as Bytes
import ./decimal-proof.bend as Decimal
import ./array-proof.bend as ArrayModel
import ./packed-proof.bend as Packed
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./ascii-proof.bend as Ascii
import ./codec-proof.bend as Codec

def width(+n: U32) -> U32:
  Bytes.u32.width(10n, U32.is_lt(n, 10), n, 1)

def width_bound(+n: U32) -> MNat.le(U32.to_nat(width(n)), 11n):
  %Equal.sym(Nat, U32.to_nat(width(n)), Decimal.count(10n, U32.is_lt(n, 10), n, 1n), Decimal.width_value(n)) : MNat.le(_, 11n)
  Decimal.count_bound(10n, U32.is_lt(n, 10), n, 1n)

def width_ne_zero(+n: U32) -> {U32.is_ne(width(n), 0) == True{} : Bool}:
  %Equal.sym(Bool, U32.is_eq(width(n), 0), Nat.is_eq(U32.to_nat(width(n)), 0n), Lemmas.u32_is_eq_nat(width(n), 0)) : {Bool.not(_) == True{} : Bool}
  %Equal.sym(Nat, U32.to_nat(width(n)), Decimal.count(10n, U32.is_lt(n, 10), n, 1n), Decimal.width_value(n)) : {Bool.not(Nat.is_eq(_, 0n)) == True{} : Bool}
  %Equal.sym(Nat, Decimal.count(10n, U32.is_lt(n, 10), n, 1n), 1n+Decimal.count(10n, U32.is_lt(n, 10), n, 0n), Decimal.count_shift(10n, U32.is_lt(n, 10), n, 0n)) : {Bool.not(Nat.is_eq(_, 0n)) == True{} : Bool}
  {==}

def depth(+len: U32) -> Nat:
  Bytes.depth(Bytes.words(len))

def allocation_bounds(n: Nat, h: MNat.le(n, 11n)) -> MNat.lt(depth(U32.from_nat(n)), 3n) & MNat.le(U32.to_nat(U32.from_nat(n)), Packed.capacity(depth(U32.from_nat(n)))):
  match n:
    case 0n:
      ({==}, {==})
    case 1n:
      ({==}, {==})
    case 2n:
      ({==}, {==})
    case 3n:
      ({==}, {==})
    case 4n:
      ({==}, {==})
    case 5n:
      ({==}, {==})
    case 6n:
      ({==}, {==})
    case 7n:
      ({==}, {==})
    case 8n:
      ({==}, {==})
    case 9n:
      ({==}, {==})
    case 10n:
      ({==}, {==})
    case 11n:
      ({==}, {==})
    case 12n+p:
      Empty.absurd(MNat.lt(depth(U32.from_nat(12n+p)), 3n) & MNat.le(U32.to_nat(U32.from_nat(12n+p)), Packed.capacity(depth(U32.from_nat(12n+p)))), Decimal.false_true(h))

def allocation(+len: U32, h: MNat.le(U32.to_nat(len), 11n)) -> MNat.lt(depth(len), 3n) & MNat.le(U32.to_nat(len), Packed.capacity(depth(len))):
  %Lemmas.u32_from_to_nat(len) : MNat.lt(depth(_), 3n) & MNat.le(U32.to_nat(_), Packed.capacity(depth(_)))
  allocation_bounds(U32.to_nat(len), h)

def alloc_model(+len: U32, h: MNat.lt(depth(len), 3n)) -> {Bytes.alloc(len) == ArrayModel.build(depth(len), ArrayModel.replicate(Lemmas.pow2(depth(len)), 0)) : Array<U32>}:
  ArrayModel.new_small(depth(len), 0, h)

def replicate_length(n: Nat, +v: U32) -> {ArrayModel.len(ArrayModel.replicate(n, v)) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %replicate_length(p, v) : {1n+ArrayModel.len(ArrayModel.replicate(p, v)) == 1n+_ : Nat}
      {==}

def width_positive(+n: U32) -> MNat.le(1n, U32.to_nat(width(n))):
  %Equal.sym(Nat, U32.to_nat(width(n)), Decimal.count(10n, U32.is_lt(n, 10), n, 1n), Decimal.width_value(n)) : MNat.le(1n, _)
  %Equal.sym(Nat, Decimal.count(10n, U32.is_lt(n, 10), n, 1n), 1n+Decimal.count(10n, U32.is_lt(n, 10), n, 0n), Decimal.count_shift(10n, U32.is_lt(n, 10), n, 0n)) : MNat.le(1n, _)
  MNat.zero_le(Decimal.count(10n, U32.is_lt(n, 10), n, 0n))

def width_lt16(+n: U32) -> MNat.lt(U32.to_nat(width(n)), 16n):
  MNat.lt_of_le_of_lt(U32.to_nat(width(n)), 11n, 16n, width_bound(n), {==})

def from_pred(+n: Nat, +i: U32, h: {1n+U32.to_nat(i) == n : Nat}) -> {U32.from_nat(Nat.sub(n, 1n)) == i : U32}:
  %h : {U32.from_nat(Nat.sub(_, 1n)) == i : U32}
  %Equal.sym(Nat, Nat.sub(U32.to_nat(i), 0n), U32.to_nat(i), MNat.sub_zero(U32.to_nat(i))) : {U32.from_nat(_) == i : U32}
  Lemmas.u32_from_to_nat(i)

def raw_pred(+n: U32, +hd: MNat.lt(depth(width(n)), 3n), +hc: MNat.le(U32.to_nat(width(n)), Packed.capacity(depth(width(n)))), r: Codec.Pred(width(n))) ->
  {Bytes.u32.read(Bytes.u32.show(n)) == Some{n} : Maybe<&2, U32>}:
  (+hp, +he) = r
  +w = width(n)
  +f = U32.to_nat(w)
  +d = depth(w)
  +i = U32.sub(w, 1)
  +l = ArrayModel.replicate(Lemmas.pow2(d), 0)
  +mem = Codec.digits(f, l, i, n)
  +hl : MNat.le(Lemmas.pow2(d), ArrayModel.len(l)) = (
    %Equal.sym(Nat, ArrayModel.len(l), Lemmas.pow2(d), replicate_length(Lemmas.pow2(d), 0)) : MNat.le(Lemmas.pow2(d), _)
    MNat.le_refl(Lemmas.pow2(d)))
  +hi = ArrayModel.lt_le_trans(U32.to_nat(i), f, Packed.capacity(d), hp, hc)
  +hf : MNat.le(f, 1n+U32.to_nat(i)) = (
    %Equal.sym(Nat, 1n+U32.to_nat(i), f, he) : MNat.le(f, _)
    MNat.le_refl(f))
  %Equal.sym(Bool, U32.is_ne(w, 0), True{}, width_ne_zero(n)) :
    {Bytes.u32.read.go(f, Bytes.peek(Bytes.u32.digits(f, Bytes.alloc(w), i, n), 0), 0, 0, _) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(Array<U32>, Bytes.alloc(w), ArrayModel.build(d, l), alloc_model(w, hd)) :
    {Bytes.u32.read.go(f, Bytes.peek(Bytes.u32.digits(f, _, i, n), 0), 0, 0, True{}) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(Array<U32>, Bytes.u32.digits(f, ArrayModel.build(d, l), i, n), ArrayModel.build(d, mem), Codec.digits_model(f, d, l, i, n, hd, hi, hl, hf)) :
    {Bytes.u32.read.go(f, Bytes.peek(_, 0), 0, 0, True{}) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(Maybe<&2, U32>, Bytes.u32.read.go(f, Bytes.peek(ArrayModel.build(d, mem), 0), 0, 0, True{}), Codec.read(f, mem, 0, 0, True{}), Codec.read_model(f, d, mem, 0, 0, True{}, hd, hc)) :
    {_ == Some{n} : Maybe<&2, U32>}
  %Equal.sym(Maybe<&2, U32>, Codec.read(f, mem, 0, 0, True{}), Ascii.read_ascii(Codec.fetch(f, mem, 0), 0, True{}), Codec.read_fetch(f, mem, 0, 0, True{})) :
    {_ == Some{n} : Maybe<&2, U32>}
  %from_pred(f, i, he) :
    {Ascii.read_ascii(Codec.fetch(f, Codec.digits(f, l, _, n), 0), 0, True{}) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(List<&2, U32>, Codec.fetch(f, Codec.digits(f, l, U32.from_nat(Nat.sub(f, 1n)), n), 0), Ascii.ascii_list(Decimal.text(f, n, Nil{})), Codec.fetch_digits_from_sub(f, d, l, n, hd, MNat.lt_of_le_of_lt(f, 11n, 12n, width_bound(n), {==}), hc, hl)) :
    {Ascii.read_ascii(_, 0, True{}) == Some{n} : Maybe<&2, U32>}
  %Equal.sym(Maybe<&2, U32>, Ascii.read_ascii(Ascii.ascii_list(Decimal.text(f, n, Nil{})), 0, True{}), Decimal.read(Decimal.text(f, n, Nil{}), 0), Ascii.read_good(Decimal.text(f, n, Nil{}), 0, Ascii.text_good(f, n, Nil{}, Unit{}))) :
    {_ == Some{n} : Maybe<&2, U32>}
  Decimal.width_roundtrip(n)

def raw_allocation(+n: U32, r: MNat.lt(depth(width(n)), 3n) & MNat.le(U32.to_nat(width(n)), Packed.capacity(depth(width(n))))) ->
  {Bytes.u32.read(Bytes.u32.show(n)) == Some{n} : Maybe<&2, U32>}:
  (hd, hc) = r
  raw_pred(n, hd, hc, Codec.predecessor_at(U32.to_nat(width(n)), width(n), {==}, width_lt16(n), width_positive(n)))

def raw(+n: U32) -> {Bytes.u32.read(Bytes.u32.show(n)) == Some{n} : Maybe<&2, U32>}:
  raw_allocation(n, allocation(width(n), width_bound(n)))
