import Base
import ./hairpin.bend as Hairpin
import ./retry.bend as Retry
import bend-kit-http@0.23.0.1/http.bend as Http
import bend-mathlib@0.7.2.0/nat.bend as MNat
import bend-kit-time@0.1.0.0/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def hs(k: String, v: String) -> Map<&2, List<&2, String>>:
  Http.set(Http.empty(), k, v)

# With no base, the URL goes as given, even when it is not absolute.
law target_no_base:
  {Hairpin.target("", "https://a.example/x") == Some{"https://a.example/x"} : Maybe<&2, String>}

law target_relative:
  {Hairpin.target("https://api.example/v1/", "users/7") == Some{"https://api.example/v1/users/7"} : Maybe<&2, String>}

law target_absolute_ref:
  {Hairpin.target("https://api.example/v1/", "http://b.example/y") == Some{"http://b.example/y"} : Maybe<&2, String>}

law target_bad_base:
  {Hairpin.target("/v1/", "users") == None{} : Maybe<&2, String>}

law merge_default:
  {Http.header(Hairpin.merge(hs("Accept", "a"), Http.empty()), "accept") == "a" : String}

# A request header replaces the default of its name, whatever the case of either.
law merge_override:
  {Http.fields(Hairpin.merge(hs("accept", "a"), hs("ACCEPT", "b")), "accept") == ["b"] : List<&2, String>}

law merge_both:
  {Http.header(Hairpin.merge(hs("x-a", "1"), hs("x-b", "2")), "x-a") == "1" : String}

# The client owns Host and Content-Length, so a default cannot set them.
law merge_reserved:
  {Http.fields(Hairpin.merge(hs("Host", "evil"), hs("content-length", "9")), "host") == Nil{} : List<&2, String>}

# ---- retry policy

def tri.br(x: Retry.Breaker & Retry.Budget & Retry.Gate) -> Retry.Breaker:
  (br, b, g) = x
  br

def tri.b(x: Retry.Breaker & Retry.Budget & Retry.Gate) -> Retry.Budget:
  (br, b, g) = x
  b

def tri.g(x: Retry.Breaker & Retry.Budget & Retry.Gate) -> Retry.Gate:
  (br, b, g) = x
  g

def left(b: Retry.Budget) -> Nat:
  Retry.Budget{l, d} = b
  l

# 1 when the gate started an attempt, else 0.
def spent(g: Retry.Gate) -> Nat:
  match g:
    case Retry.GateGo{}:
      1n
    case Retry.GateNo{why}:
      0n

# One event of a trace: an attempt asks to start, or an attempt ends.
type Ev is Data:
  EvTry{now: Nat}
  EvDone{now: Nat, failed: Bool}

# The attempts a trace starts.
def runs(evs: List<&2, Ev>, +br: Retry.Breaker, +b: Retry.Budget) -> Nat:
  match evs:
    case Nil{}:
      0n
    case Con{e, rest}:
      match e:
        case EvTry{+now}:
          Nat.add(spent(tri.g(Retry.admit(br, b, now))), runs(rest, tri.br(Retry.admit(br, b, now)), tri.b(Retry.admit(br, b, now))))
        case EvDone{+now, failed}:
          runs(rest, Retry.Breaker.done(br, now, failed), b)

# The breaker after a trace.
def runs.br(evs: List<&2, Ev>, +br: Retry.Breaker, +b: Retry.Budget) -> Retry.Breaker:
  match evs:
    case Nil{}:
      br
    case Con{e, rest}:
      match e:
        case EvTry{+now}:
          runs.br(rest, tri.br(Retry.admit(br, b, now)), tri.b(Retry.admit(br, b, now)))
        case EvDone{+now, failed}:
          runs.br(rest, Retry.Breaker.done(br, now, failed), b)

# The budget after a trace.
def runs.b(evs: List<&2, Ev>, +br: Retry.Breaker, +b: Retry.Budget) -> Retry.Budget:
  match evs:
    case Nil{}:
      b
    case Con{e, rest}:
      match e:
        case EvTry{+now}:
          runs.b(rest, tri.br(Retry.admit(br, b, now)), tri.b(Retry.admit(br, b, now)))
        case EvDone{+now, failed}:
          runs.b(rest, Retry.Breaker.done(br, now, failed), b)

# One admission takes exactly one attempt from the budget when it starts one, and none otherwise.
law budget_step_exact:
  for +br: Retry.Breaker
  for +b: Retry.Budget
  for +now: Nat
  {Nat.add(spent(tri.g(Retry.admit(br, b, now))), left(tri.b(Retry.admit(br, b, now)))) == left(b) : Nat}

# Over any trace, the attempts started plus the budget left equal the budget given.
law budget_trace_exact:
  for evs: List<&2, Ev>
  for +br: Retry.Breaker
  for +b: Retry.Budget
  {Nat.add(runs(evs, br, b), left(runs.b(evs, br, b))) == left(b) : Nat}

# Admitted attempts never exceed the shared budget, whatever the breaker, clock, and outcomes.
law budget_bound:
  for +evs: List<&2, Ev>
  for +br: Retry.Breaker
  for +b: Retry.Budget
  MNat.le(runs(evs, br, b), left(b))

# A nested layer that hands its budget back cannot reset or multiply it: the inner and outer attempts
# together stay within the one budget.
law budget_nested:
  for +inner: List<&2, Ev>
  for +outer: List<&2, Ev>
  for +br: Retry.Breaker
  for +b: Retry.Budget
  MNat.le(Nat.add(runs(inner, br, b), runs(outer, runs.br(inner, br, b), runs.b(inner, br, b))), left(b))

# No attempt starts at or after the deadline.
law deadline_denies:
  for br: Retry.Breaker
  for left: Nat
  for +d: Nat
  for k: Nat
  {tri.g(Retry.admit(br, Retry.Budget{left, Some{d}}, Nat.add(d, k))) == Retry.GateNo{Retry.DenyLate{}} : Retry.Gate}

law deadline_before_admits:
  for left: Nat
  for d: Nat
  {tri.g(Retry.admit(Retry.BreakerOff{}, Retry.Budget{1n+left, Some{1n+d}}, d)) == Retry.GateGo{} : Retry.Gate}

# The backoff step never passes cap, and equal jitter stays in [d / 2, d].
law delay_le_cap:
  for n: Nat
  for +base: Nat
  for +cap: Nat
  MNat.le(Retry.delay(n, base, cap), cap)

law jitter_floor:
  for +d: Nat
  for r: Nat
  MNat.le(Nat.div(d, 2n), Retry.jitter(d, r))

law jitter_ceiling:
  for +d: Nat
  for +r: Nat
  MNat.le(Retry.jitter(d, r), d)

# Every wait, the server's included, is at most cap.
law wait_le_cap:
  for +after: Maybe<&2, Nat>
  for +a: Nat
  for +base: Nat
  for +cap: U32
  for +d: Maybe<&2, Nat>
  for +n: Nat
  for +r: Nat
  MNat.le(Retry.wait(after, Retry.Policy{a, base, cap, d}, n, r), U32.to_nat(cap))

# So the wait fits a U32 sleep exactly: no overflow, no wrap.
law wait_fits_u32:
  for +after: Maybe<&2, Nat>
  for p: Retry.Policy
  for +n: Nat
  for +r: Nat
  {U32.to_nat(U32.from_nat(Retry.wait(after, p, n, r))) == Retry.wait(after, p, n, r) : Nat}

# Non-retryable outcomes never schedule another attempt.
law plan_settled_stops:
  for p: Retry.Policy
  for b: Retry.Budget
  for n: Nat
  for now: Nat
  for r: Nat
  {Retry.plan(Retry.Settled{}, p, b, n, now, r) == Retry.PlanStop{} : Retry.Plan}

law plan_unsafe_stops:
  for p: Retry.Policy
  for b: Retry.Budget
  for n: Nat
  for now: Nat
  for r: Nat
  {Retry.plan(Retry.Unsafe{}, p, b, n, now, r) == Retry.PlanStop{} : Retry.Plan}

law plan_spent_stops:
  for after: Maybe<&2, Nat>
  for p: Retry.Policy
  for d: Maybe<&2, Nat>
  for n: Nat
  for now: Nat
  for r: Nat
  {Retry.plan(Retry.Transient{after}, p, Retry.Budget{0n, d}, n, now, r) == Retry.PlanStop{} : Retry.Plan}

# A wait that would reach the deadline stops instead.
law plan_late_stops:
  for after: Maybe<&2, Nat>
  for p: Retry.Policy
  for left: Nat
  for n: Nat
  for +now: Nat
  for r: Nat
  {Retry.plan(Retry.Transient{after}, p, Retry.Budget{1n+left, Some{now}}, n, now, r) == Retry.PlanStop{} : Retry.Plan}

# ---- circuit breaker

def fst(x: Retry.State & Bool) -> Retry.State:
  (s, ok) = x
  s

def busy(s: Retry.State) -> Nat:
  match s:
    case Retry.CircuitClosed{fs}:
      0n
    case Retry.CircuitOpen{u}:
      0n
    case Retry.CircuitHalf{k}:
      k

# A closed circuit holds fewer than threshold failures in its window.
def under(+t: Nat, s: Retry.State) -> Bool:
  match s:
    case Retry.CircuitClosed{fs}:
      Nat.is_lt(List.length(&2, Nat, fs), t)
    case Retry.CircuitOpen{u}:
      True{}
    case Retry.CircuitHalf{k}:
      True{}

law closed_admits:
  for c: Retry.Circuit
  for fs: List<&2, Nat>
  for now: Nat
  {Retry.State.admit(c, Retry.CircuitClosed{fs}, now) == (Retry.CircuitClosed{fs}, True{}) : Retry.State & Bool}

law open_denies_before_cooldown:
  for c: Retry.Circuit
  for +now: Nat
  for +k: Nat
  {Retry.State.admit(c, Retry.CircuitOpen{1n+Nat.add(now, k)}, now) == (Retry.CircuitOpen{1n+Nat.add(now, k)}, False{}) : Retry.State & Bool}

law open_probes_after_cooldown:
  for t: Nat
  for w: Nat
  for cd: Nat
  for p: Nat
  for +u: Nat
  for k: Nat
  {Retry.State.admit(Retry.Circuit{t, w, cd, 1n+p}, Retry.CircuitOpen{u}, Nat.add(u, k)) == (Retry.CircuitHalf{1n}, True{}) : Retry.State & Bool}

# Half-open never has more than probes attempts in flight.
law probe_limit:
  for +c: Retry.Circuit
  for +s: Retry.State
  for now: Nat
  for h: MNat.le(busy(s), Retry.Circuit.probes(c))
  MNat.le(busy(fst(Retry.State.admit(c, s, now))), Retry.Circuit.probes(c))

# An attempt that ends leaves no probe in flight: the circuit closes, opens, or stays as it was.
law done_frees_probes:
  for c: Retry.Circuit
  for s: Retry.State
  for now: Nat
  for failed: Bool
  {busy(Retry.State.done(c, s, now, failed)) == 0n : Nat}

law half_success_closes:
  for c: Retry.Circuit
  for k: Nat
  for now: Nat
  {Retry.State.done(c, Retry.CircuitHalf{k}, now, False{}) == Retry.CircuitClosed{Nil{}} : Retry.State}

law half_failure_opens:
  for t: Nat
  for w: Nat
  for cd: Nat
  for p: Nat
  for k: Nat
  for now: Nat
  {Retry.State.done(Retry.Circuit{t, w, cd, p}, Retry.CircuitHalf{k}, now, True{}) == Retry.CircuitOpen{Nat.add(now, cd)} : Retry.State}

law open_ignores_done:
  for c: Retry.Circuit
  for u: Nat
  for now: Nat
  for failed: Bool
  {Retry.State.done(c, Retry.CircuitOpen{u}, now, failed) == Retry.CircuitOpen{u} : Retry.State}

# A success while closed clears the failures, so only failures in a row open the circuit.
law closed_success_clears:
  for c: Retry.Circuit
  for fs: List<&2, Nat>
  for now: Nat
  {Retry.State.done(c, Retry.CircuitClosed{fs}, now, False{}) == Retry.CircuitClosed{Nil{}} : Retry.State}

# A failure leaves the circuit closed only while the window holds fewer than threshold failures.
law closed_failure_under_threshold:
  for +t: Nat
  for w: Nat
  for cd: Nat
  for p: Nat
  for fs: List<&2, Nat>
  for +now: Nat
  {under(t, Retry.State.done(Retry.Circuit{t, w, cd, p}, Retry.CircuitClosed{fs}, now, True{})) == True{} : Bool}

def circ() -> Retry.Circuit:
  Retry.Circuit{2n, 100n, 50n, 1n}

# Two failures inside the window open the circuit; one outside it has expired.
law window_trips:
  {Retry.State.done(circ(), Retry.State.done(circ(), Retry.CircuitClosed{Nil{}}, 10n, True{}), 60n, True{}) == Retry.CircuitOpen{110n} : Retry.State}

law window_expires:
  {Retry.State.done(circ(), Retry.State.done(circ(), Retry.CircuitClosed{Nil{}}, 10n, True{}), 110n, True{}) == Retry.CircuitClosed{[110n]} : Retry.State}

law window_success_resets:
  {Retry.State.done(circ(), Retry.State.done(circ(), Retry.State.done(circ(), Retry.CircuitClosed{Nil{}}, 10n, True{}), 20n, False{}), 30n, True{}) == Retry.CircuitClosed{[30n]} : Retry.State}

# A full half-open circuit denies a second probe.
law half_full_denies:
  {Retry.State.admit(circ(), Retry.CircuitHalf{1n}, 500n) == (Retry.CircuitHalf{1n}, False{}) : Retry.State & Bool}

# ---- Hairpin's outcome classification

def hint(x: Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) -> Maybe<&2, String>:
  (res, m) = x
  m

def epoch() -> Time.Instant:
  Time.Instant.of_unix(Int.I64.from_u32(0))

def judged(+idem: Bool, r: Result<&1, &1, Http.Err, Http.Res>) -> Retry.Outcome:
  Hairpin.outcome(idem, hint(Http.retry.judge(True{}, r)), epoch())

def res(+status: U32, h: Map<&2, List<&2, String>>) -> Result<&1, &1, Http.Err, Http.Res>:
  Done{Http.Res{status, h, Bytes.new(0)}}

# A transient failure of an idempotent request may try again, after the server's Retry-After.
law outcome_get_503:
  {judged(True{}, res(503, hs("retry-after", "2"))) == Retry.Transient{Some{2000n}} : Retry.Outcome}

law outcome_get_connect:
  {judged(True{}, Fail{Http.ErrConnect{61, "refused"}}) == Retry.Transient{None{}} : Retry.Outcome}

# The same failure of a POST counts against the breaker, but is never tried again.
law outcome_post_503:
  {judged(False{}, res(503, Http.empty())) == Retry.Unsafe{} : Retry.Outcome}

# Success, a client error, and an error that would repeat are settled.
law outcome_settled:
  {[judged(True{}, res(200, Http.empty())), judged(True{}, res(404, Http.empty())), judged(True{}, Fail{Http.ErrDns{}})] == [Retry.Settled{}, Retry.Settled{}, Retry.Settled{}] : List<&2, Retry.Outcome>}
