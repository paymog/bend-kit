import Base
import ./bits.bend as Bits
import ./LAWS.bend as Laws
import ./writer-proof.bend as W
import ./array-proof.bend as A
import ./prefix-proof.bend as Prefix
import ./invariant-proof.bend as I
import ./readback-proof.bend as R
import bend-kit-lemmas@0.1.5.1/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N

def built_eta(+msb: Bool, +s: W.State) ->
  {W.build(msb, s) == W.build(msb, W.State{R.image(s), R.depth(s), W.position(s)}) : Bits.Writer}:
  match s:
    case W.State{t, dep, p}:
      {==}

# Keep the scalar state's position in the bound: https://github.com/bendlang/bend/issues/1071.
def field_position_bound(+t: A.Tree, +dep: U32, +p: U32, +n: U32, +limit: Nat,
  room: N.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), limit)) ->
  N.lt(Nat.add(U32.to_nat(W.position(W.State{t, dep, p})), U32.to_nat(n)), limit):
  N.lt_of_le_of_lt(Nat.add(U32.to_nat(p), U32.to_nat(n)),
    Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), limit,
    N.le_add_right(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), room)

# Compare scalar positions before substituting a writer: https://github.com/bendlang/bend/issues/1071.
def position_step(+p: U32, +q: U32, +end: U32, +n: U32, e: {q == p : U32},
  h: {U32.to_nat(end) == Nat.add(U32.to_nat(q), U32.to_nat(n)) : Nat}) ->
  {U32.to_nat(end) == Nat.add(U32.to_nat(p), U32.to_nat(n)) : Nat}:
  %e : {U32.to_nat(end) == Nat.add(U32.to_nat(_), U32.to_nat(n)) : Nat}
  h

# Compose against an opaque output state: https://github.com/bendlang/bend/issues/1071.
def read_composed(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +out: W.State, +n: U32, +v: U32,
  step: {U32.to_nat(W.position(out)) == Nat.add(U32.to_nat(p), U32.to_nat(n)) : Nat},
  field: {U32.to_nat(Bits.field(msb, n, W.window(msb, R.image(out), p))) ==
    Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat},
  bridge: {Laws.put(msb, W.build(msb, W.State{t, dep, p}), n, v) == W.build(msb, out) : Bits.Writer},
  room: N.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), L.pow2(32n)),
  hn: N.le(U32.to_nat(n), 32n)) ->
  {Laws.read_after_write_at(msb, n, v, W.build(msb, W.State{t, dep, p})) ==
    Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}:
  Prefix.read_result(msb, t, dep, p, R.image(out), R.depth(out), W.position(out), n, v,
    step, room, hn, field,
    Equal.trans(Bits.Writer, Laws.put(msb, W.build(msb, W.State{t, dep, p}), n, v), W.build(msb, out),
      W.build(msb, W.State{R.image(out), R.depth(out), W.position(out)}), bridge, built_eta(msb, out)))



def model_read_fields(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  valid: W.valid(msb, W.State{t, dep, p}),
  +room: N.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), L.pow2(32n)),
  +hn: N.le(U32.to_nat(n), 32n)) ->
  {Laws.read_after_write_at(msb, n, v, W.build(msb, W.State{t, dep, p})) ==
    Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}:
  read_composed(msb, t, dep, p, W.write(msb, W.State{t, dep, p}, n, v), n, v,
    position_step(p, W.position(W.State{t, dep, p}), W.position(W.write(msb, W.State{t, dep, p}, n, v)), n, {==},
      Prefix.appended_position(msb, W.State{t, dep, p}, n, v, hn,
        field_position_bound(t, dep, p, n, L.pow2(32n), room))),
    R.write_field(msb, t, dep, p, n, v, valid, room, hn),
    W.put_order_bridge(msb, W.State{t, dep, p}, n, v), room, hn)

def built_prefix_eta(+msb: Bool, +s: W.State) ->
  {W.build(msb, s) == W.build(msb, W.State{Prefix.image(s), Prefix.depth(s), W.position(s)}) : Bits.Writer}:
  Equal.cong(W.State, Bits.Writer, q => W.build(msb, q), s,
    W.State{Prefix.image(s), Prefix.depth(s), W.position(s)}, Prefix.state_eta(s))

def model_read_transport(+msb: Bool, +s: W.State, +n: U32, +v: U32,
  h: {Laws.read_after_write_at(msb, n, v,
    W.build(msb, W.State{Prefix.image(s), Prefix.depth(s), W.position(s)})) ==
    Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}) ->
  {Laws.read_after_write_at(msb, n, v, W.build(msb, s)) ==
    Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}:
  %Equal.sym(Bits.Writer, W.build(msb, s),
    W.build(msb, W.State{Prefix.image(s), Prefix.depth(s), W.position(s)}), built_prefix_eta(msb, s)) :
    {Laws.read_after_write_at(msb, n, v, _) == Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}
  h

def model_read(+msb: Bool, +s: W.State, +n: U32, +v: U32,
  valid: W.valid(msb, s),
  room: N.lt(Nat.add(Nat.add(U32.to_nat(W.position(s)), U32.to_nat(n)), 31n), L.pow2(32n)),
  hn: N.le(U32.to_nat(n), 32n)) ->
  {Laws.read_after_write_at(msb, n, v, W.build(msb, s)) ==
    Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}:
  model_read_transport(msb, s, n, v,
    model_read_fields(msb, Prefix.image(s), Prefix.depth(s), W.position(s), n, v,
      Prefix.valid_eta(msb, s, valid), room, hn))

# Preserve the initial position in the bound: https://github.com/bendlang/bend/issues/1071.
def prefix_invariant_bound(+bits: Nat, +n: Nat, +limit: Nat,
  h: N.lt(Nat.add(Nat.add(bits, n), 31n), limit)) ->
  N.lt(Nat.add(Nat.add(U32.to_nat(W.position(W.new())), bits), 31n), limit):
  Prefix.prefix_room_bound(bits, n, limit, h)

def prefix_valid(+fs: List<&2, Laws.F>, +msb: Bool, +n: U32,
  room: N.lt(Nat.add(Nat.add(Laws.prefix_bits(fs), U32.to_nat(n)), 31n), L.pow2(32n))) ->
  W.valid(msb, W.puts(fs, msb, W.new())):
  I.puts_preserves(fs, msb, W.new(), W.new_valid(msb),
    prefix_invariant_bound(Laws.prefix_bits(fs), U32.to_nat(n), L.pow2(32n), room))

def read_after_write(+msb: Bool, +fs: List<&2, Laws.F>, +n: U32, +v: U32,
  width: N.le(U32.to_nat(n), 32n),
  +room: N.lt(Nat.add(Nat.add(Laws.prefix_bits(fs), U32.to_nat(n)), 31n), L.pow2(32n))) ->
  {Laws.read_after_write(msb, fs, n, v) == Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}:
  +s = W.puts(fs, msb, W.new())
  Equal.trans(Maybe<&2, Nat>, Laws.read_after_write(msb, fs, n, v),
    Laws.read_after_write_at(msb, n, v, W.build(msb, s)),
    Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))},
    Prefix.prefix_read_bridge(fs, msb, n, v),
    model_read(msb, s, n, v, prefix_valid(fs, msb, n, room),
      Prefix.room_at_position(Laws.prefix_bits(fs), W.position(s), n, L.pow2(32n),
        Prefix.prefix_position(fs, msb, n, room), room), width))

# Adapt the public Boolean hypotheses before specialization: https://github.com/bendlang/bend/issues/1071.
def order_le(-a: Nat, -b: Nat, h: {Nat.is_le(a, b) == True{} : Bool}) -> N.le(a, b):
  h

def order_lt(-a: Nat, -b: Nat, h: {Nat.is_lt(a, b) == True{} : Bool}) -> N.lt(a, b):
  h

def lawful_read_after_write(+msb: Bool, +fs: List<&2, Laws.F>, +n: U32, +v: U32,
  width: {Nat.is_le(U32.to_nat(n), 32n) == True{} : Bool},
  room: {Nat.is_lt(Nat.add(Nat.add(Laws.prefix_bits(fs), U32.to_nat(n)), 31n), L.pow2(32n)) == True{} : Bool}) ->
  {Laws.read_after_write(msb, fs, n, v) == Some{Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n)))} : Maybe<&2, Nat>}:
  read_after_write(msb, fs, n, v, order_le(U32.to_nat(n), 32n, width),
    order_lt(Nat.add(Nat.add(Laws.prefix_bits(fs), U32.to_nat(n)), 31n), L.pow2(32n), room))
