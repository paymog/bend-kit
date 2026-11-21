import Base
import ./bits.bend as Bits
import ./LAWS.bend as Laws
import ./writer-proof.bend as W
import ./array-proof.bend as A
import bend-kit-lemmas@0.1.5.1/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N
import bend-mathlib@0.8.0.0/u32.bend as U

def image(s: W.State) -> A.Tree:
  W.State{t, depth, pos} = s
  t

def min_width(+n: U32, h: N.le(U32.to_nat(n), 32n)) -> {U32.min(n, 32) == n : U32}:
  L.u32_to_nat_inj(U32.min(n, 32), n,
    Equal.trans(Nat, U32.to_nat(U32.min(n, 32)), Nat.min(U32.to_nat(n), 32n), U32.to_nat(n),
      U.u32_min_to_nat(n, 32), N.min_eq_left(U32.to_nat(n), 32n, h)))

def width_position(+p: Nat, +end: Nat, +n: U32, +m: U32, e: {m == n : U32},
  h: {end == Nat.add(p, U32.to_nat(m)) : Nat}) ->
  {end == Nat.add(p, U32.to_nat(n)) : Nat}:
  %e : {end == Nat.add(p, U32.to_nat(_)) : Nat}
  h


def appended_position(+msb: Bool, +s: W.State, +n: U32, +v: U32,
  hn: N.le(U32.to_nat(n), 32n)) ->
  {W.position(W.write(msb, s, n, v)) == Nat.add(W.position(s), U32.to_nat(n)) : Nat}:
  width_position(W.position(s), W.position(W.write(msb, s, n, v)),
    n, U32.min(n, 32), min_width(n, hn), W.write_position_nat(msb, s, n, v))

# Pass scalar positions without matching a bounded state: https://github.com/bendlang/bend/issues/1071.
def read_result(+msb: Bool, +t: A.Tree, +depth: U32, +pos: Nat,
  +written: A.Tree, +next_depth: U32, +end: Nat, +n: U32, +v: U32,
  step: {end == Nat.add(pos, U32.to_nat(n)) : Nat},
  room: N.lt(Nat.add(Nat.add(pos, U32.to_nat(n)), 31n), L.pow2(35n)),
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
        q => Laws.read_after_skip(True{}, n, Bits.Reader.skip(Bits.Reader.new(Bits.Writer.finish(q)), 0n)),
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

def room_at_position(+bits: Nat, +p: Nat, +n: U32, +limit: Nat,
  e: {p == bits : Nat},
  h: N.lt(Nat.add(Nat.add(bits, U32.to_nat(n)), 31n), limit)) ->
  N.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), limit):
  L.lt_rw(Nat.add(Nat.add(p, U32.to_nat(n)), 31n),
    Nat.add(Nat.add(bits, U32.to_nat(n)), 31n), limit,
    Equal.cong(Nat, Nat, q => Nat.add(Nat.add(q, U32.to_nat(n)), 31n), p, bits, e), h)

def prefix_room_bound(+p: Nat, +n: Nat, +limit: Nat,
  h: N.lt(Nat.add(Nat.add(p, n), 31n), limit)) ->
  N.lt(Nat.add(p, 31n), limit):
  N.lt_of_le_of_lt(Nat.add(p, 31n), Nat.add(Nat.add(p, n), 31n), limit,
    N.add_le_add_right(p, Nat.add(p, n), 31n, N.le_add_right(p, n)), h)

def prefix_position(+fs: List<&2, Laws.F>, +msb: Bool) ->
  {W.position(W.puts(fs, msb, W.new())) == Laws.prefix_bits(fs) : Nat}:
  W.puts_position(fs, msb, W.new())
