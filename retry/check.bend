import Base
import ./retry.bend as Retry

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def waits(p: Retry.Plan) -> Nat:
  match p:
    case Retry.PlanStop{}:
      0n
    case Retry.PlanWait{ms}:
      ms

def gate(x: Retry.Breaker & Retry.Budget & Retry.Gate) -> Bool:
  (br, b, g) = x
  match g:
    case Retry.GateGo{}:
      True{}
    case Retry.GateNo{why}:
      False{}

def policy() -> Retry.Policy:
  Retry.Policy{3n, 500n, 30000, Some{10000n}}

def circ() -> Retry.Circuit:
  Retry.Circuit{2n, 1000n, 5000n, 1n}

# Two failures inside the window open the circuit until 5000 ms after the second one.
def tripped() -> Retry.Breaker:
  Retry.Breaker.done(Retry.Breaker.done(Retry.Breaker.new(circ()), 100n, True{}), 200n, True{})

def main() -> IO(Unit):
  do IO<Unit>:
    require(Nat.is_eq(Retry.delay(3n, 500n, 30000n), 4000n), "backoff doubles per retry")
    require(Nat.is_eq(Retry.delay(10n, 500n, 30000n), 30000n), "backoff stops at the cap")
    require(Nat.is_eq(Retry.jitter(4000n, 7n), 2007n), "equal jitter starts at half the delay")
    require(Nat.is_eq(waits(Retry.plan(Retry.Transient{Some{1200n}}, policy(), Retry.Budget{2n, Some{10000n}}, 0n, 0n, 0n)), 1200n), "a server wait wins over backoff")
    require(Nat.is_eq(waits(Retry.plan(Retry.Transient{Some{1200n}}, policy(), Retry.Budget{2n, Some{10000n}}, 0n, 9000n, 0n)), 0n), "a wait that reaches the deadline stops")
    require(Nat.is_eq(waits(Retry.plan(Retry.Failed{}, policy(), Retry.Budget{2n, None{}}, 0n, 0n, 0n)), 0n), "a failure that would repeat stops")
    require(Bool.not(gate(Retry.admit(Retry.Breaker.done(Retry.Breaker.done(Retry.Breaker.new(circ()), 100n, Retry.failed(Retry.Failed{})), 200n, Retry.failed(Retry.Failed{})), Retry.Budget.new(1n, 0n, None{}), 300n))), "failures that would repeat open the circuit")
    require(gate(Retry.admit(Retry.Breaker.done(Retry.Breaker.done(Retry.Breaker.new(circ()), 100n, Retry.failed(Retry.Rejected{})), 200n, Retry.failed(Retry.Rejected{})), Retry.Budget.new(1n, 0n, None{}), 300n)), "client errors do not open the circuit")
    require(gate(Retry.admit(Retry.BreakerOff{}, Retry.Budget.new(1n, 0n, None{}), 0n)), "a fresh budget admits")
    require(Bool.not(gate(Retry.admit(tripped(), Retry.Budget.new(1n, 0n, None{}), 300n))), "an open circuit denies")
    require(gate(Retry.admit(tripped(), Retry.Budget.new(1n, 0n, None{}), 5200n)), "the cooldown ends with a probe")
    IO.print("retry: ok")
