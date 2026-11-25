import Base
import ./pure.bend as Stream
import bend-mathlib@0.8.0.0/u32.bend as MU32
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./LAWS.bend as Laws

# Reflexivity over pure decisions; no claim about native or JavaScript effects.
def Laws.chunk_zero():
  {==}

def Laws.chunk_minimum():
  {==}

def Laws.chunk_maximum():
  {==}

def Laws.chunk_excess():
  {==}

def Laws.request_chunk_bound():
  {==}

def Laws.request_cap_bound():
  {==}

def Laws.request_probe():
  {==}

def Laws.eof_before_cap():
  {==}

def Laws.eof_at_cap():
  {==}

def Laws.nonempty_probe():
  {==}

def Laws.short_read_continues():
  {==}

def Laws.chunk_interval(chunk):
  {==}

def le_nat_sym(+a: U32, +b: U32) ->
  {Nat.is_le(U32.to_nat(a), U32.to_nat(b)) == U32.is_le(a, b) : Bool}:
  Equal.sym(Bool, U32.is_le(a, b), Nat.is_le(U32.to_nat(a), U32.to_nat(b)),
    MU32.u32_is_le_to_nat(a, b))

def min_nat_sym(+a: U32, +b: U32) ->
  {Nat.min(U32.to_nat(a), U32.to_nat(b)) == U32.to_nat(U32.min(a, b)) : Nat}:
  Equal.sym(Nat, U32.to_nat(U32.min(a, b)), Nat.min(U32.to_nat(a), U32.to_nat(b)),
    MU32.u32_min_to_nat(a, b))

def min_bounds(+chunk: U32, +remaining: U32) ->
  {U32.is_le(U32.min(chunk, remaining), chunk) == True{} : Bool} &
  {U32.is_le(U32.min(chunk, remaining), remaining) == True{} : Bool}:
  (
    %le_nat_sym(U32.min(chunk, remaining), chunk) : {_ == True{} : Bool}
    %min_nat_sym(chunk, remaining) : {Nat.is_le(_, U32.to_nat(chunk)) == True{} : Bool}
    MNat.min_le_left(U32.to_nat(chunk), U32.to_nat(remaining)),
    %le_nat_sym(U32.min(chunk, remaining), remaining) : {_ == True{} : Bool}
    %min_nat_sym(chunk, remaining) : {Nat.is_le(_, U32.to_nat(remaining)) == True{} : Bool}
    MNat.min_le_right(U32.to_nat(chunk), U32.to_nat(remaining))
  )

def Laws.request_bounds(chunk, remaining, nonzero):
  %Equal.sym(Bool, U32.is_zero(remaining), False{}, nonzero) : {
    U32.is_le(Stream.request.flags(_, chunk, remaining), chunk) == True{} : Bool} &
    {U32.is_le(Stream.request.flags(_, chunk, remaining), remaining) == True{} : Bool}
  min_bounds(chunk, remaining)

def Laws.request_probe_general(chunk):
  {==}

def Laws.read_eof_general(len, remaining, zero):
  %Equal.sym(Bool, U32.is_zero(len), True{}, zero) : {Stream.read.action.flags(_, U32.is_zero(remaining)) == Stream.End{} : Stream.ReadAction}
  {==}

def Laws.read_probe_general(len, remaining, nonempty, probe):
  %Equal.sym(Bool, U32.is_zero(len), False{}, nonempty) : {Stream.read.action.flags(_, U32.is_zero(remaining)) == Stream.Over{} : Stream.ReadAction}
  %Equal.sym(Bool, U32.is_zero(remaining), True{}, probe) : {Stream.read.action.flags(False{}, _) == Stream.Over{} : Stream.ReadAction}
  {==}

def Laws.read_forward_general(len, remaining, nonempty, nonzero):
  %Equal.sym(Bool, U32.is_zero(len), False{}, nonempty) : {Stream.read.action.flags(_, U32.is_zero(remaining)) == Stream.Forward{} : Stream.ReadAction}
  %Equal.sym(Bool, U32.is_zero(remaining), False{}, nonzero) : {Stream.read.action.flags(False{}, _) == Stream.Forward{} : Stream.ReadAction}
  {==}
