import Base
import ./recurrence.bend as R

law invalid_zero:
  for previous: Nat
  for completion: Nat
  for cadence: R.Cadence
  {R.plan(previous, completion, 0n, cadence) == None{} : Maybe<&2, R.Plan>}

law fixed_delay:
  for previous: Nat
  for completion: Nat
  for p: Nat
  {R.plan(previous, completion, 1n+p, R.FixedDelay{}) ==
    Some{R.Planned{Nil{}, Nat.add(completion, 1n+p)}} : Maybe<&2, R.Plan>}

# These equations specify named policies, phase anchoring, and exact replay prefix.
law fixed_rate_skip:
  for +previous: Nat
  for +completion: Nat
  for +p: Nat
  {R.plan(previous, completion, 1n+p, R.FixedRate{R.Skip{}}) ==
    Some{R.Planned{Nil{}, Nat.add(previous,
      Nat.mul(1n+Nat.div(Nat.sub(completion, previous), 1n+p), 1n+p))}}
    : Maybe<&2, R.Plan>}

law fixed_rate_catch_up:
  for +previous: Nat
  for +completion: Nat
  for +p: Nat
  for +bound: Nat
  {R.plan(previous, completion, 1n+p, R.FixedRate{R.CatchUp{bound}}) ==
    Some{R.Planned{R.ticks(Nat.min(bound, Nat.div(Nat.sub(completion, previous), 1n+p)),
      previous, 1n+p), Nat.add(previous,
      Nat.mul(1n+Nat.div(Nat.sub(completion, previous), 1n+p), 1n+p))}}
    : Maybe<&2, R.Plan>}

law replay_bounded:
  for +previous: Nat
  for +completion: Nat
  for +p: Nat
  for +bound: Nat
  {Nat.is_le(List.length(&2, Nat, R.replay(R.positive(R.FixedRate{R.CatchUp{bound}},
    previous, completion, 1n+p))), bound) == True{} : Bool}

# Every positive planner branch returns a deadline strictly beyond completion.
law future_deadline:
  for +previous: Nat
  for +completion: Nat
  for +p: Nat
  for cadence: R.Cadence
  {Nat.is_lt(completion, R.next(R.positive(cadence, previous, completion, 1n+p))) == True{} : Bool}

# The last skipped/replayed rate tick is not in the future (when the previous
# scheduled tick has completed). Together with future_deadline this proves
# the returned deadline is the first future anchored tick, not just any one.
law last_due:
  for +previous: Nat
  for +completion: Nat
  for +p: Nat
  for h: {Nat.is_le(previous, completion) == True{} : Bool}
  {Nat.is_le(Nat.add(previous,
    Nat.mul(Nat.div(Nat.sub(completion, previous), 1n+p), 1n+p)), completion) == True{} : Bool}

# Addition is monotone on arbitrary Nat: deadlines never wrap below their origin.
law no_wrapping:
  for +origin: Nat
  for period: Nat
  {Nat.is_le(origin, Nat.add(origin, period)) == True{} : Bool}

# For any one-based index in the exact replay prefix, its anchored tick is due.
law replay_tick_due:
  for +previous: Nat
  for +completion: Nat
  for +p: Nat
  for +bound: Nat
  for +i: Nat
  for h: {Nat.is_le(previous, completion) == True{} : Bool}
  for hi: {Nat.is_le(i, Nat.min(bound,
    Nat.div(Nat.sub(completion, previous), 1n+p))) == True{} : Bool}
  {Nat.is_le(Nat.add(previous, Nat.mul(i, 1n+p)), completion) == True{} : Bool}

# Exposed validation entry point is connected to the planner used by safety laws.
law accepted_positive:
  for +previous: Nat
  for +completion: Nat
  for +p: Nat
  for +cadence: R.Cadence
  {R.plan(previous, completion, 1n+p, cadence) ==
    Some{R.positive(cadence, previous, completion, 1n+p)} : Maybe<&2, R.Plan>}
