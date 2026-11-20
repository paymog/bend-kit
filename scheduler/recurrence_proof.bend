import Base
import bend-mathlib@0.8.0.0/nat.bend as N
import ./recurrence.bend as R
import ./recurrence_laws.bend as Laws

def Laws.invalid_zero(previous, completion, cadence):
  {==}

def Laws.fixed_delay(previous, completion, p):
  {==}

def Laws.fixed_rate_skip(previous, completion, p):
  {==}

def Laws.fixed_rate_catch_up(previous, completion, p, bound):
  {==}

def ticks_length(count: Nat, +previous: Nat, +period: Nat)
  -> {List.length(&2, Nat, R.ticks(count, previous, period)) == count : Nat}:
  match count:
    case 0n:
      {==}
    case 1n+n:
      %ticks_length(n, Nat.add(previous, period), period) : {1n+List.length(&2, Nat,
        R.ticks(n, Nat.add(previous, period), period)) == 1n+_ : Nat}
      {==}

def Laws.replay_bounded(previous, completion, p, bound):
  %Equal.sym(Nat, List.length(&2, Nat, R.ticks(
    Nat.min(bound, Nat.div(Nat.sub(completion, previous), 1n+p)), previous, 1n+p)),
    Nat.min(bound, Nat.div(Nat.sub(completion, previous), 1n+p)),
    ticks_length(Nat.min(bound, Nat.div(Nat.sub(completion, previous), 1n+p)), previous, 1n+p))
    : {Nat.is_le(_, bound) == True{} : Bool}
  N.min_le_left(bound, Nat.div(Nat.sub(completion, previous), 1n+p))

def quotient_future(+elapsed: Nat, +p: Nat)
  -> N.lt(elapsed, Nat.mul(1n+Nat.div(elapsed, 1n+p), 1n+p)):
  %N.not_is_le(Nat.mul(1n+Nat.div(elapsed, 1n+p), 1n+p), elapsed)
    : {_ == True{} : Bool}
  %N.le_div_iff_mul_le(1n+Nat.div(elapsed, 1n+p), elapsed, p)
    : {Bool.not(_) == True{} : Bool}
  %Equal.sym(Bool, Nat.is_le(1n+Nat.div(elapsed, 1n+p), Nat.div(elapsed, 1n+p)),
    False{}, N.not_le_of_lt(Nat.div(elapsed, 1n+p), 1n+Nat.div(elapsed, 1n+p),
      N.lt_succ_self(Nat.div(elapsed, 1n+p)))) : {Bool.not(_) == True{} : Bool}
  {==}

def fixed_rate_future(+previous: Nat, +completion: Nat, +p: Nat,
  order: Or(N.le(previous, completion), N.le(completion, previous)))
  -> N.lt(completion,
    Nat.add(previous, Nat.mul(1n+Nat.div(Nat.sub(completion, previous), 1n+p), 1n+p))):
  match order:
    case Inl{h}:
      %N.add_sub_of_le(previous, completion, h)
        : N.lt(_, Nat.add(previous,
          Nat.mul(1n+Nat.div(Nat.sub(completion, previous), 1n+p), 1n+p)))
      N.add_lt_add_left(Nat.sub(completion, previous),
        Nat.mul(1n+Nat.div(Nat.sub(completion, previous), 1n+p), 1n+p), previous,
        quotient_future(Nat.sub(completion, previous), p))
    case Inr{+h}:
      %Equal.sym(Nat, Nat.sub(completion, previous), 0n,
        N.sub_eq_zero_of_le(completion, previous, h))
        : N.lt(completion, Nat.add(previous, Nat.mul(1n+Nat.div(_, 1n+p), 1n+p)))
      %Equal.sym(Nat, Nat.add(p, 0n), p, N.add_zero(p))
        : N.lt(completion, Nat.add(previous, 1n+_))
      N.lt_of_le_of_lt(completion, previous, Nat.add(previous, 1n+p), h,
        N.lt_add_of_pos_right(previous, p))

def Laws.future_deadline(previous, completion, p, cadence):
  match cadence:
    case R.FixedDelay{}:
      N.lt_add_of_pos_right(completion, p)
    case R.FixedRate{policy}:
      fixed_rate_future(previous, completion, p, N.le_total(previous, completion))

def due_tick(+previous: Nat, +completion: Nat, +p: Nat, +i: Nat,
  h: N.le(previous, completion), hi: N.le(i, Nat.div(Nat.sub(completion, previous), 1n+p)))
  -> N.le(Nat.add(previous, Nat.mul(i, 1n+p)), completion):
  %N.sub_add_cancel(completion, previous, h)
    : N.le(Nat.add(previous, Nat.mul(i, 1n+p)), _)
  %N.add_comm(previous, Nat.sub(completion, previous))
    : N.le(Nat.add(previous, Nat.mul(i, 1n+p)), _)
  N.add_le_add_left(Nat.mul(i, 1n+p), Nat.sub(completion, previous), previous,
    (%N.le_div_iff_mul_le(i, Nat.sub(completion, previous), p)
      : {_ == True{} : Bool}; hi))

def Laws.last_due(previous, completion, p, h):
  due_tick(previous, completion, p, Nat.div(Nat.sub(completion, previous), 1n+p), h,
    N.le_refl(Nat.div(Nat.sub(completion, previous), 1n+p)))

def Laws.no_wrapping(origin, period):
  N.le_add_right(origin, period)

def Laws.replay_tick_due(previous, completion, p, bound, i, h, hi):
  due_tick(previous, completion, p, i, h,
    N.le_trans(i, Nat.min(bound, Nat.div(Nat.sub(completion, previous), 1n+p)),
      Nat.div(Nat.sub(completion, previous), 1n+p), hi,
      N.min_le_right(bound, Nat.div(Nat.sub(completion, previous), 1n+p))))

def Laws.accepted_positive(previous, completion, p, cadence):
  {==}
