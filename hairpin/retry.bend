# Retry policy: a shared attempt budget, an operation deadline, bounded backoff, and a circuit breaker.
# All times are ms on one monotonic clock. The caller reads the clock; these defs are pure.
import Base

# left: attempts the whole operation may still start, the first one included. Nested layers share one Budget.
# deadline: no attempt starts at or after this time. None: no deadline.
type Budget is Data:
  Budget{left: Nat, deadline: Maybe<&2, Nat>}

type Deny is Data:
  DenyLate{}
  DenySpent{}
  DenyOpen{}

type Gate is Data:
  GateGo{}
  GateNo{why: Deny}

# threshold: failures in a row, each inside window ms of the newest, that open the circuit. cooldown: ms it stays open.
# probes: attempts allowed at once while half-open.
type Circuit is Data:
  Circuit{threshold: Nat, window: Nat, cooldown: Nat, probes: Nat}

# Closed: the failures since the last success that are still inside the window, newest first.
# Open: no attempt before until. Half: probes in flight.
type State is Data:
  CircuitClosed{fails: List<&2, Nat>}
  CircuitOpen{until: Nat}
  CircuitHalf{busy: Nat}

type Breaker is Data:
  BreakerOff{}
  BreakerOn{circuit: Circuit, state: State}

# Settled: a success, or a failure that another try would repeat. Unsafe: a transient failure of a
# request that must not repeat. Transient: another try can help; after is the server's wait in ms.
type Outcome is Data:
  Settled{}
  Unsafe{}
  Transient{after: Maybe<&2, Nat>}

# attempts: tries in one layer, the first one included. base: the first backoff in ms. cap: the longest wait in ms.
# deadline: ms from the start of the operation to its deadline. None: no deadline.
type Policy is Data:
  Policy{attempts: Nat, base: Nat, cap: U32, deadline: Maybe<&2, Nat>}

type Plan is Data:
  PlanStop{}
  PlanWait{ms: Nat}

# ---- budget

def Budget.new(+attempts: Nat, +now: Nat, ms: Maybe<&2, Nat>) -> Budget:
  match ms:
    case None{}:
      Budget{attempts, None{}}
    case Some{m}:
      Budget{attempts, Some{Nat.add(now, m)}}

def Budget.late(+now: Nat, d: Maybe<&2, Nat>) -> Bool:
  match d:
    case None{}:
      False{}
    case Some{t}:
      Nat.is_le(t, now)

# ---- circuit

# The failure times still inside the window: now < t + window. Newest first, so the first old time ends the list.
def prune(+now: Nat, +window: Nat, fs: List<&2, Nat>) -> List<&2, Nat>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{+t, rest}:
      Bool.pick(List<&2, Nat>, Nat.is_lt(now, Nat.add(t, window)), Con{t, prune(now, window, rest)}, Nil{})

def Circuit.probes(c: Circuit) -> Nat:
  Circuit{t, w, cd, p} = c
  p

def Circuit.cooldown(c: Circuit) -> Nat:
  Circuit{t, w, cd, p} = c
  cd

def half.admit(go: Bool, +k: Nat) -> State & Bool:
  match go:
    case True{}:
      (CircuitHalf{1n+k}, True{})
    case False{}:
      (CircuitHalf{k}, False{})

def open.admit(early: Bool, +p: Nat, +u: Nat) -> State & Bool:
  match early:
    case True{}:
      (CircuitOpen{u}, False{})
    case False{}:
      half.admit(Nat.is_lt(0n, p), 0n)

# Closed admits. Open admits nothing before until; at or after until it turns half-open and admits a probe.
# Half-open admits while fewer than probes are in flight.
def State.admit(+c: Circuit, s: State, +now: Nat) -> State & Bool:
  match s:
    case CircuitClosed{fs}:
      (CircuitClosed{fs}, True{})
    case CircuitOpen{+u}:
      open.admit(Nat.is_lt(now, u), Circuit.probes(c), u)
    case CircuitHalf{+k}:
      half.admit(Nat.is_lt(k, Circuit.probes(c)), k)

def closed.trip(under: Bool, fs: List<&2, Nat>, +until: Nat) -> State:
  match under:
    case True{}:
      CircuitClosed{fs}
    case False{}:
      CircuitOpen{until}

def closed.fail(+c: Circuit, fs: List<&2, Nat>, +now: Nat) -> State:
  Circuit{+t, +w, +cd, p} = c
  +kept = {Con{now, prune(now, w, fs)} : List<&2, Nat>}
  closed.trip(Nat.is_lt(List.length(&2, Nat, kept), t), kept, Nat.add(now, cd))

# A closed success clears the failures. A closed failure opens the circuit when the window then holds threshold
# failures. A half-open success closes it; a half-open failure opens it again for cooldown. An attempt that ends
# while open changes nothing.
def State.done(+c: Circuit, s: State, +now: Nat, failed: Bool) -> State:
  match s:
    case CircuitClosed{fs}:
      match failed:
        case False{}:
          CircuitClosed{Nil{}}
        case True{}:
          closed.fail(c, fs, now)
    case CircuitOpen{u}:
      CircuitOpen{u}
    case CircuitHalf{k}:
      match failed:
        case False{}:
          CircuitClosed{Nil{}}
        case True{}:
          CircuitOpen{Nat.add(now, Circuit.cooldown(c))}

def Breaker.new(c: Circuit) -> Breaker:
  BreakerOn{c, CircuitClosed{Nil{}}}

def Breaker.on(+c: Circuit, x: State & Bool) -> Breaker & Bool:
  (s, ok) = x
  (BreakerOn{c, s}, ok)

def Breaker.admit(br: Breaker, +now: Nat) -> Breaker & Bool:
  match br:
    case BreakerOff{}:
      (BreakerOff{}, True{})
    case BreakerOn{+c, s}:
      Breaker.on(c, State.admit(c, s, now))

def Breaker.done(br: Breaker, +now: Nat, failed: Bool) -> Breaker:
  match br:
    case BreakerOff{}:
      BreakerOff{}
    case BreakerOn{+c, s}:
      BreakerOn{c, State.done(c, s, now, failed)}

# ---- admission

def admit.ok(ok: Bool, br: Breaker, +p: Nat, d: Maybe<&2, Nat>) -> Breaker & Budget & Gate:
  match ok:
    case True{}:
      (br, Budget{p, d}, GateGo{})
    case False{}:
      (br, Budget{1n+p, d}, GateNo{DenyOpen{}})

def admit.breaker(x: Breaker & Bool, +p: Nat, d: Maybe<&2, Nat>) -> Breaker & Budget & Gate:
  (br, ok) = x
  admit.ok(ok, br, p, d)

def admit.late(late: Bool, br: Breaker, left: Nat, d: Maybe<&2, Nat>, +now: Nat) -> Breaker & Budget & Gate:
  match late:
    case True{}:
      (br, Budget{left, d}, GateNo{DenyLate{}})
    case False{}:
      match left:
        case 0n:
          (br, Budget{0n, d}, GateNo{DenySpent{}})
        case 1n+p:
          admit.breaker(Breaker.admit(br, now), p, d)

# Ask to start one attempt at now. The deadline is checked first, then the budget, then the breaker.
# Only GateGo takes one attempt from the budget.
def admit(br: Breaker, b: Budget, +now: Nat) -> Breaker & Budget & Gate:
  Budget{left, +d} = b
  admit.late(Budget.late(now, d), br, left, d, now)

# ---- backoff

# min(cap, base * 2^n), doubled one step at a time, so no step passes cap.
def delay(n: Nat, +base: Nat, +cap: Nat) -> Nat:
  match n:
    case 0n:
      Nat.min(base, cap)
    case 1n+p:
      +d = delay(p, base, cap)
      Nat.min(Nat.add(d, d), cap)

# Equal jitter: d / 2, plus r mod (d / 2 + 1). The wait is in [d / 2, d] for every r.
def jitter(+d: Nat, +r: Nat) -> Nat:
  +h = Nat.div(d, 2n)
  Nat.add(h, Nat.mod(r, 1n+h))

# The wait before retry n (0 first): the server's wait when it gave one, else the jittered backoff. At most cap.
def wait(after: Maybe<&2, Nat>, p: Policy, +n: Nat, +r: Nat) -> Nat:
  match after:
    case None{}:
      Policy{a, +base, +cap, d} = p
      jitter(delay(n, base, U32.to_nat(cap)), r)
    case Some{+ms}:
      Policy{a, base, +cap, d} = p
      Nat.min(ms, U32.to_nat(cap))

def plan.left(left: Nat, +w: Nat, d: Maybe<&2, Nat>, +now: Nat) -> Plan:
  match left:
    case 0n:
      PlanStop{}
    case 1n+k:
      Bool.pick(Plan, Budget.late(Nat.add(now, w), d), PlanStop{}, PlanWait{w})

def plan.at(+w: Nat, b: Budget, +now: Nat) -> Plan:
  Budget{left, d} = b
  plan.left(left, w, d, now)

# After an attempt ends at now: stop, or wait ms and then ask admit again. Settled and Unsafe always stop.
# A transient outcome stops when the budget is spent or the wait would reach the deadline.
def plan(o: Outcome, p: Policy, b: Budget, +n: Nat, +now: Nat, +r: Nat) -> Plan:
  match o:
    case Settled{}:
      PlanStop{}
    case Unsafe{}:
      PlanStop{}
    case Transient{after}:
      plan.at(wait(after, p, n, r), b, now)

# Unsafe and Transient count as failures for the breaker.
def failed(o: Outcome) -> Bool:
  match o:
    case Settled{}:
      False{}
    case Unsafe{}:
      True{}
    case Transient{after}:
      True{}
