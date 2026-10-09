import Base
import bend-mathlib@0.7.2.0/nat.bend as MNat
import ../lemmas/lemmas.bend as Lemmas
import ./retry.bend as Retry
import ./LAWS.bend as Laws

def Laws.target_no_base():
  {==}

def Laws.target_relative():
  {==}

def Laws.target_absolute_ref():
  {==}

def Laws.target_bad_base():
  {==}

def Laws.merge_default():
  {==}

def Laws.merge_override():
  {==}

def Laws.merge_both():
  {==}

def Laws.merge_reserved():
  {==}

# ---- budget

def step.ok(ok: Bool, br: Retry.Breaker, p: Nat, d: Maybe<&2, Nat>)
  -> {Nat.add(Laws.spent(Laws.tri.g(Retry.admit.ok(ok, br, p, d))), Laws.left(Laws.tri.b(Retry.admit.ok(ok, br, p, d)))) == 1n+p : Nat}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def step.breaker(x: Retry.Breaker & Bool, p: Nat, d: Maybe<&2, Nat>)
  -> {Nat.add(Laws.spent(Laws.tri.g(Retry.admit.breaker(x, p, d))), Laws.left(Laws.tri.b(Retry.admit.breaker(x, p, d)))) == 1n+p : Nat}:
  match x:
    case (br, ok):
      step.ok(ok, br, p, d)

def step.late(late: Bool, br: Retry.Breaker, l: Nat, d: Maybe<&2, Nat>, now: Nat)
  -> {Nat.add(Laws.spent(Laws.tri.g(Retry.admit.late(late, br, l, d, now))), Laws.left(Laws.tri.b(Retry.admit.late(late, br, l, d, now)))) == l : Nat}:
  match late:
    case True{}:
      {==}
    case False{}:
      match l:
        case 0n:
          {==}
        case 1n+p:
          step.breaker(Retry.Breaker.admit(br, now), p, d)

def Laws.budget_step_exact(br, b, now):
  match b:
    case Retry.Budget{l, d}:
      step.late(Retry.Budget.late(now, d), br, l, d, now)

def Laws.budget_trace_exact(evs, br, b):
  match evs:
    case Nil{}:
      {==}
    case Con{e, rest}:
      match e:
        case Laws.EvTry{+now}:
          +s = Laws.spent(Laws.tri.g(Retry.admit(br, b, now)))
          +br2 = Laws.tri.br(Retry.admit(br, b, now))
          +b2 = Laws.tri.b(Retry.admit(br, b, now))
          %MNat.add_assoc_sym(s, Laws.runs(rest, br2, b2), Laws.left(Laws.runs.b(rest, br2, b2)))
            : {_ == Laws.left(b) : Nat}
          %Equal.sym(Nat, Nat.add(Laws.runs(rest, br2, b2), Laws.left(Laws.runs.b(rest, br2, b2))), Laws.left(b2), Laws.budget_trace_exact(rest, br2, b2))
            : {Nat.add(s, _) == Laws.left(b) : Nat}
          Laws.budget_step_exact(br, b, now)
        case Laws.EvDone{now, failed}:
          Laws.budget_trace_exact(rest, Retry.Breaker.done(br, now, failed), b)

def Laws.budget_bound(evs, br, b):
  MNat.le_of_add_eq(Laws.runs(evs, br, b), Laws.left(Laws.runs.b(evs, br, b)), Laws.left(b), Laws.budget_trace_exact(evs, br, b))

def Laws.budget_nested(inner, outer, br, b):
  +r1 = Laws.runs(inner, br, b)
  +br1 = Laws.runs.br(inner, br, b)
  +b1 = Laws.runs.b(inner, br, b)
  +r2 = Laws.runs(outer, br1, b1)
  %Laws.budget_trace_exact(inner, br, b)
    : MNat.le(Nat.add(r1, r2), _)
  MNat.add_le_add_left(r2, Laws.left(b1), r1, Laws.budget_bound(outer, br1, b1))

def succ_not_le(d: Nat) -> {Nat.is_le(1n+d, d) == False{} : Bool}:
  match d:
    case 0n:
      {==}
    case 1n+p:
      succ_not_le(p)

def add_not_lt(u: Nat, k: Nat) -> {Nat.is_lt(Nat.add(u, k), u) == False{} : Bool}:
  match u:
    case 0n:
      match k:
        case 0n:
          {==}
        case 1n+q:
          {==}
    case 1n+v:
      add_not_lt(v, k)

def Laws.deadline_denies(br, left, d, k):
  %Equal.sym(Bool, Nat.is_le(d, Nat.add(d, k)), True{}, MNat.le_add_right(d, k))
    : {Laws.tri.g(Retry.admit.late(_, br, left, Some{d}, Nat.add(d, k))) == Retry.GateNo{Retry.DenyLate{}} : Retry.Gate}
  {==}

def Laws.deadline_before_admits(left, d):
  %Equal.sym(Bool, Nat.is_le(1n+d, d), False{}, succ_not_le(d))
    : {Laws.tri.g(Retry.admit.late(_, Retry.BreakerOff{}, 1n+left, Some{1n+d}, d)) == Retry.GateGo{} : Retry.Gate}
  {==}

# ---- backoff

def Laws.delay_le_cap(n, base, cap):
  match n:
    case 0n:
      MNat.min_le_right(base, cap)
    case 1n+p:
      +dp = Retry.delay(p, base, cap)
      MNat.min_le_right(Nat.add(dp, dp), cap)

def Laws.jitter_floor(d, r):
  MNat.le_add_right(Nat.div(d, 2n), Nat.mod(r, 1n+Nat.div(d, 2n)))

def half_twice(+d: Nat) -> {Nat.add(Nat.add(Nat.div(d, 2n), Nat.div(d, 2n)), Nat.mod(d, 2n)) == d : Nat}:
  %MNat.double_eq_add(Nat.div(d, 2n)) : {Nat.add(_, Nat.mod(d, 2n)) == d : Nat}
  MNat.double_div_two_add_mod_two(d)

def Laws.jitter_ceiling(d, r):
  +h = Nat.div(d, 2n)
  +m = Nat.mod(r, 1n+h)
  MNat.le_trans(Nat.add(h, m), Nat.add(h, h), d,
    MNat.add_le_add_left(m, h, h, MNat.le_of_lt_succ(m, h, MNat.mod_lt(r, h))),
    MNat.le_of_add_eq(Nat.add(h, h), Nat.mod(d, 2n), d, half_twice(d)))

def Laws.wait_le_cap(after, a, base, cap, d, n, r):
  match after:
    case None{}:
      +dl = Retry.delay(n, base, U32.to_nat(cap))
      MNat.le_trans(Retry.jitter(dl, r), dl, U32.to_nat(cap), Laws.jitter_ceiling(dl, r), Laws.delay_le_cap(n, base, U32.to_nat(cap)))
    case Some{ms}:
      MNat.min_le_right(ms, U32.to_nat(cap))

def Laws.wait_fits_u32(after, p, n, r):
  match p:
    case Retry.Policy{+a, +base, +cap, +d}:
      +w = Retry.wait(after, Retry.Policy{a, base, cap, d}, n, r)
      Lemmas.u32_to_from_nat(w, MNat.lt_of_le_of_lt(w, U32.to_nat(cap), Lemmas.pow2(32n),
        Laws.wait_le_cap(after, a, base, cap, d, n, r), Lemmas.u32_to_nat_lt(cap)))

# ---- plan

def Laws.plan_settled_stops(p, b, n, now, r):
  {==}

def Laws.plan_unsafe_stops(p, b, n, now, r):
  {==}

def Laws.plan_spent_stops(after, p, d, n, now, r):
  {==}

def Laws.plan_late_stops(after, p, left, n, now, r):
  +w = Retry.wait(after, p, n, r)
  %Equal.sym(Bool, Nat.is_le(now, Nat.add(now, w)), True{}, MNat.le_add_right(now, w))
    : {Bool.pick(Retry.Plan, _, Retry.PlanStop{}, Retry.PlanWait{w}) == Retry.PlanStop{} : Retry.Plan}
  {==}

# ---- circuit

def Laws.closed_admits(c, fs, now):
  {==}

def Laws.open_denies_before_cooldown(c, now, k):
  %Equal.sym(Bool, Nat.is_lt(now, 1n+Nat.add(now, k)), True{}, MNat.lt_succ_of_le(now, Nat.add(now, k), MNat.le_add_right(now, k)))
    : {Retry.open.admit(_, Retry.Circuit.probes(c), 1n+Nat.add(now, k)) == (Retry.CircuitOpen{1n+Nat.add(now, k)}, False{}) : Retry.State & Bool}
  {==}

def Laws.open_probes_after_cooldown(t, w, cd, p, u, k):
  %Equal.sym(Bool, Nat.is_lt(Nat.add(u, k), u), False{}, add_not_lt(u, k))
    : {Retry.open.admit(_, 1n+p, u) == (Retry.CircuitHalf{1n}, True{}) : Retry.State & Bool}
  {==}

def pl.half(go: Bool, +k: Nat, +p: Nat, e: {go == Nat.is_lt(k, p) : Bool}, h: MNat.le(k, p))
  -> MNat.le(Laws.busy(Laws.fst(Retry.half.admit(go, k))), p):
  match go:
    case True{}:
      MNat.succ_le_of_lt(k, p, Equal.sym(Bool, True{}, Nat.is_lt(k, p), e))
    case False{}:
      h

def pl.open(early: Bool, +p: Nat, u: Nat) -> MNat.le(Laws.busy(Laws.fst(Retry.open.admit(early, p, u))), p):
  match early:
    case True{}:
      MNat.zero_le(p)
    case False{}:
      pl.half(Nat.is_lt(0n, p), 0n, p, {==}, MNat.zero_le(p))

def Laws.probe_limit(c, s, now, h):
  match s:
    case Retry.CircuitClosed{fs}:
      MNat.zero_le(Retry.Circuit.probes(c))
    case Retry.CircuitOpen{u}:
      pl.open(Nat.is_lt(now, u), Retry.Circuit.probes(c), u)
    case Retry.CircuitHalf{k}:
      pl.half(Nat.is_lt(k, Retry.Circuit.probes(c)), k, Retry.Circuit.probes(c), {==}, h)

def df.trip(under: Bool, fs: List<&2, Nat>, until: Nat) -> {Laws.busy(Retry.closed.trip(under, fs, until)) == 0n : Nat}:
  match under:
    case True{}:
      {==}
    case False{}:
      {==}

def df.closed(c: Retry.Circuit, fs: List<&2, Nat>, +now: Nat) -> {Laws.busy(Retry.closed.fail(c, fs, now)) == 0n : Nat}:
  match c:
    case Retry.Circuit{t, w, cd, p}:
      +kept = {Con{now, Retry.prune(now, w, fs)} : List<&2, Nat>}
      df.trip(Nat.is_lt(List.length(&2, Nat, kept), t), kept, Nat.add(now, cd))

def Laws.done_frees_probes(c, s, now, failed):
  match s:
    case Retry.CircuitClosed{fs}:
      match failed:
        case False{}:
          {==}
        case True{}:
          df.closed(c, fs, now)
    case Retry.CircuitOpen{u}:
      {==}
    case Retry.CircuitHalf{k}:
      match failed:
        case False{}:
          {==}
        case True{}:
          {==}

def Laws.half_success_closes(c, k, now):
  {==}

def Laws.half_failure_opens(t, w, cd, p, k, now):
  {==}

def Laws.open_ignores_done(c, u, now, failed):
  {==}

def Laws.closed_success_clears(c, fs, now):
  {==}

def Laws.window_success_resets():
  {==}

def ut.trip(under: Bool, +t: Nat, +kept: List<&2, Nat>, until: Nat, e: {under == Nat.is_lt(List.length(&2, Nat, kept), t) : Bool})
  -> {Laws.under(t, Retry.closed.trip(under, kept, until)) == True{} : Bool}:
  match under:
    case True{}:
      Equal.sym(Bool, True{}, Nat.is_lt(List.length(&2, Nat, kept), t), e)
    case False{}:
      {==}

def Laws.closed_failure_under_threshold(t, w, cd, p, fs, now):
  +kept = {Con{now, Retry.prune(now, w, fs)} : List<&2, Nat>}
  ut.trip(Nat.is_lt(List.length(&2, Nat, kept), t), t, kept, Nat.add(now, cd), {==})

def Laws.window_trips():
  {==}

def Laws.window_expires():
  {==}

def Laws.half_full_denies():
  {==}

def Laws.outcome_get_503():
  {==}

def Laws.outcome_get_connect():
  {==}

def Laws.outcome_post_503():
  {==}

def Laws.outcome_settled():
  {==}
