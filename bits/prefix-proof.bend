import Base
import ./bits.bend as Bits
import ./LAWS.bend as Laws
import ./writer-proof.bend as W
import ./array-proof.bend as A
import ./position-proof.bend as Position
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N
import bend-mathlib@0.8.0.0/u32.bend as U
import ./field-proof.bend as Field

def image(s: W.State) -> A.Tree:
  W.State{t, depth, pos} = s
  t

def min_width(+n: U32, h: N.le(U32.to_nat(n), 32n)) -> {U32.min(n, 32) == n : U32}:
  L.u32_to_nat_inj(U32.min(n, 32), n,
    Equal.trans(Nat, U32.to_nat(U32.min(n, 32)), Nat.min(U32.to_nat(n), 32n), U32.to_nat(n),
      U.u32_min_to_nat(n, 32), N.min_eq_left(U32.to_nat(n), 32n, h)))

# Transport the width without normalizing the writer: https://github.com/bendlang/bend/issues/1071.
def width_bound(+p: Nat, +n: U32, +m: U32, +limit: Nat, e: {m == n : U32},
  h: N.lt(Nat.add(p, U32.to_nat(n)), limit)) ->
  N.lt(Nat.add(p, U32.to_nat(m)), limit):
  %Equal.sym(U32, m, n, e) : N.lt(Nat.add(p, U32.to_nat(_)), limit)
  h

def width_position(+p: Nat, +end: Nat, +n: U32, +m: U32, e: {m == n : U32},
  h: {end == Nat.add(p, U32.to_nat(m)) : Nat}) ->
  {end == Nat.add(p, U32.to_nat(n)) : Nat}:
  %e : {end == Nat.add(p, U32.to_nat(_)) : Nat}
  h


def appended_position(+msb: Bool, +s: W.State, +n: U32, +v: U32,
  +hn: N.le(U32.to_nat(n), 32n),
  room: N.lt(Nat.add(U32.to_nat(W.position(s)), U32.to_nat(n)), L.pow2(32n))) ->
  {U32.to_nat(W.position(W.write(msb, s, n, v))) == Nat.add(U32.to_nat(W.position(s)), U32.to_nat(n)) : Nat}:
  width_position(U32.to_nat(W.position(s)), U32.to_nat(W.position(W.write(msb, s, n, v))),
    n, U32.min(n, 32), min_width(n, hn),
    W.write_position_nat(msb, s, n, v,
      width_bound(U32.to_nat(W.position(s)), n, U32.min(n, 32), L.pow2(32n), min_width(n, hn), room)))

# Pass scalar positions without matching a bounded state: https://github.com/bendlang/bend/issues/1071.
def read_result(+msb: Bool, +t: A.Tree, +depth: U32, +pos: U32,
  +written: A.Tree, +next_depth: U32, +end: U32, +n: U32, +v: U32,
  step: {U32.to_nat(end) == Nat.add(U32.to_nat(pos), U32.to_nat(n)) : Nat},
  room: N.lt(Nat.add(Nat.add(U32.to_nat(pos), U32.to_nat(n)), 31n), L.pow2(32n)),
  hn: N.le(U32.to_nat(n), 32n),
  field: {U32.to_nat(Bits.field(msb, n, W.window(msb, written, pos))) == Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat},
  bridge: {Laws.put(msb, W.build(msb, W.State{t, depth, pos}), n, v) == W.build(msb, W.State{written, next_depth, end}) : Bits.Writer}) ->
  {Laws.read_after_write_at(msb, n, v, W.build(msb, W.State{t, depth, pos})) == Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}:
  %Equal.sym(Bits.Writer, Laws.put(msb, W.build(msb, W.State{t, depth, pos}), n, v),
    W.build(msb, W.State{written, next_depth, end}), bridge) :
    {Laws.read_after_skip(msb, n, Bits.Reader.skip(Bits.Reader.new(Bits.Writer.finish(_)), pos)) ==
      Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}
  W.finished_read(msb, written, pos, n, end, Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))), step, room, hn, field)

def prefix_nonempty_bridge(+n: U32, +v: U32, +tail: List<&2, Laws.F>, +msb: Bool) ->
  {Laws.puts(Con{Laws.F{n, v}, tail}, msb, Bits.Writer.new()) ==
    W.build(msb, W.puts(Con{Laws.F{n, v}, tail}, msb, W.new())) : Bits.Writer}:
  %Equal.sym(Bits.Writer, Laws.put(msb, Bits.Writer.new(), n, v),
    W.build(msb, W.write(msb, W.new(), n, v)), W.initial_write_bridge(msb, n, v)) :
    {Laws.puts(tail, msb, _) == W.build(msb, W.puts(Con{Laws.F{n, v}, tail}, msb, W.new())) : Bits.Writer}
  W.puts_bridge(tail, msb, W.write(msb, W.new(), n, v))

def div_small(+a: Nat, b: Nat, h: N.lt(a, b)) -> {Nat.div(a, b) == 0n : Nat}:
  match b:
    case 0n:
      Empty.absurd({Nat.div(a, 0n) == 0n : Nat}, N.lt_zero(a)(h))
    case 1n++p:
      N.div_eq_zero_of_le(a, p, N.le_of_lt_succ(a, p, h))

def zero_field(msb: Bool, +v: U32) -> {U32.to_nat(Bits.field(msb, 0, v)) == 0n : Nat}:
  match msb:
    case False{}:
      Equal.trans(Nat, U32.to_nat(U32.and(v, Bits.mask(0))), Nat.mod(U32.to_nat(v), 1n), 0n,
        Field.mask_mod(v, 0, {==}), N.mod_one(U32.to_nat(v)))
    case True{}:
      Equal.trans(Nat, U32.to_nat(U32.shrn(v, 32n)), Nat.div(U32.to_nat(v), L.pow2(32n)), 0n,
        Field.shrn_nat(v, 32n), div_small(U32.to_nat(v), L.pow2(32n), L.u32_to_nat_lt(v)))

def zero_written_field(+msb: Bool, +s: W.State, +v: U32) ->
  {U32.to_nat(Bits.field(msb, 0, W.window(msb, image(W.write(msb, s, 0, v)), W.position(s)))) ==
    Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(0))) : Nat}:
  Equal.trans(Nat,
    U32.to_nat(Bits.field(msb, 0, W.window(msb, image(W.write(msb, s, 0, v)), W.position(s)))),
    0n, Nat.mod(U32.to_nat(v), 1n),
    zero_field(msb, W.window(msb, image(W.write(msb, s, 0, v)), W.position(s))),
    Equal.sym(Nat, Nat.mod(U32.to_nat(v), 1n), 0n, N.mod_one(U32.to_nat(v))))

def initial_put_order(+msb: Bool, +n: U32, +v: U32) ->
  {Laws.put(msb, Bits.Writer.new(), n, v) == Laws.put(msb, W.build(msb, W.new()), n, v) : Bits.Writer}:
  Equal.trans(Bits.Writer, Laws.put(msb, Bits.Writer.new(), n, v),
    W.build(msb, W.write(msb, W.new(), n, v)), Laws.put(msb, W.build(msb, W.new()), n, v),
    W.initial_write_bridge(msb, n, v),
    Equal.sym(Bits.Writer, Laws.put(msb, W.build(msb, W.new()), n, v),
      W.build(msb, W.write(msb, W.new(), n, v)), W.put_order_bridge(msb, W.new(), n, v)))

def initial_read_bridge(msb: Bool, +n: U32, +v: U32) ->
  {Laws.read_after_write_at(msb, n, v, Bits.Writer.new()) ==
    Laws.read_after_write_at(msb, n, v, W.build(msb, W.new())) : Maybe<&2, Nat>}:
  match msb:
    case False{}:
      {==}
    case True{}:
      Equal.cong(Bits.Writer, Maybe<&2, Nat>,
        q => Laws.read_after_skip(True{}, n, Bits.Reader.skip(Bits.Reader.new(Bits.Writer.finish(q)), 0)),
        Laws.put(True{}, Bits.Writer.new(), n, v), Laws.put(True{}, W.build(True{}, W.new()), n, v),
        initial_put_order(True{}, n, v))

def prefix_read_bridge(+fs: List<&2, Laws.F>, +msb: Bool, +n: U32, +v: U32) ->
  {Laws.read_after_write(msb, fs, n, v) ==
    Laws.read_after_write_at(msb, n, v, W.build(msb, W.puts(fs, msb, W.new()))) : Maybe<&2, Nat>}:
  match fs:
    case Nil{}:
      initial_read_bridge(msb, n, v)
    case Con{Laws.F{+width, +value}, +tail}:
      Equal.cong(Bits.Writer, Maybe<&2, Nat>, q => Laws.read_after_write_at(msb, n, v, q),
        Laws.puts(Con{Laws.F{width, value}, tail}, msb, Bits.Writer.new()),
        W.build(msb, W.puts(Con{Laws.F{width, value}, tail}, msb, W.new())),
        prefix_nonempty_bridge(width, value, tail, msb))

def depth(s: W.State) -> U32:
  W.State{t, dep, pos} = s
  dep

def state_eta(+s: W.State) ->
  {s == W.State{image(s), depth(s), W.position(s)} : W.State}:
  match s:
    case W.State{t, dep, pos}:
      {==}

def valid_eta(+msb: Bool, +s: W.State, h: W.valid(msb, s)) ->
  W.valid(msb, W.State{image(s), depth(s), W.position(s)}):
  %state_eta(s) : W.valid(msb, _)
  h
