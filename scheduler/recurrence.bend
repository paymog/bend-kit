# Pure recurrence on arbitrary-precision Nat ticks: no wrapping or U32 conversion.
import Base

type Missed is Data:
  Skip{}
  CatchUp{bound: Nat}

type Cadence is Data:
  FixedDelay{}
  FixedRate{policy: Missed}

type Plan is Data:
  Planned{replay: List<&2, Nat>, next: Nat}

def replay(p: Plan) -> List<&2, Nat>:
  match p:
    case Planned{ticks, next}:
      ticks

def next(p: Plan) -> Nat:
  match p:
    case Planned{ticks, next}:
      next

# Generate only the bounded replay prefix, never the skipped remainder.
def ticks(count: Nat, +previous: Nat, +period: Nat) -> List<&2, Nat>:
  match count:
    case 0n:
      Nil{}
    case 1n+n:
      +deadline = Nat.add(previous, period)
      Con{deadline, ticks(n, deadline, period)}

def limit(policy: Missed, overdue: Nat) -> Nat:
  match policy:
    case Skip{}:
      0n
    case CatchUp{bound}:
      Nat.min(bound, overdue)

# A tick equal to completion is overdue. The already-completed previous tick
# is excluded. A positive period keeps all arithmetic exact, without overflow.
def rate(+previous: Nat, +completion: Nat, +period: Nat, policy: Missed) -> Plan:
  +overdue = Nat.div(Nat.sub(completion, previous), period)
  Planned{ticks(limit(policy, overdue), previous, period),
    Nat.add(previous, Nat.mul(1n+overdue, period))}

def positive(cadence: Cadence, +previous: Nat, +completion: Nat, +period: Nat) -> Plan:
  match cadence:
    case FixedDelay{}:
      Planned{Nil{}, Nat.add(completion, period)}
    case FixedRate{policy}:
      rate(previous, completion, period, policy)

# None is an explicit invalid-zero-period result, not a zero cadence.
def plan(previous: Nat, completion: Nat, period: Nat, cadence: Cadence) -> Maybe<&2, Plan>:
  match period:
    case 0n:
      None{}
    case 1n+p:
      Some{positive(cadence, previous, completion, 1n+p)}
