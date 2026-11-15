import Base
import ./commands.bend as C
import ./LAWS.bend as Laws

def Laws.duplicate_replays(S, P, R, E, eq, dup_p, dup_r, decide, q, o, t, p, same, s, at):
  %Equal.sym(Bool, eq(q, p), True{}, same) : {C.Keep{C.replayed(R, _, o)} == C.Keep{C.Replayed{o}} : C.Step<S, P, R, E>}
  {==}

def Laws.conflict_rejected(S, P, R, E, eq, dup_p, dup_r, decide, q, o, t, p, differ, s, at):
  %Equal.sym(Bool, eq(q, p), False{}, differ) : {C.Keep{C.replayed(R, _, o)} == C.Keep{C.Conflict{}} : C.Step<S, P, R, E>}
  {==}

def Laws.accept_recorded(S, P, R, E, eq, dup_p, copy_p, dup_r, copy_r, decide, s, p, at, s2, r, es, e):
  %Equal.sym(P & P, dup_p(p), (p, p), copy_p(p)) : {C.fresh(~S, ~P, ~R, ~E, ~dup_r, ~decide, _, s, at) == C.Write{s2, C.Record{p, C.Accepted{r}, at}, C.Fresh{C.Accepted{r}}, es} : C.Step<S, P, R, E>}
  %Equal.sym(C.Decision<S, R, E>, decide(s, p), C.Accept{s2, r, es}, e) : {C.decided(~S, ~P, ~R, ~E, ~dup_r, _, p, at) == C.Write{s2, C.Record{p, C.Accepted{r}, at}, C.Fresh{C.Accepted{r}}, es} : C.Step<S, P, R, E>}
  %Equal.sym(R & R, dup_r(r), (r, r), copy_r(r)) : {C.accepted(S, P, R, E, _, s2, p, at, es) == C.Write{s2, C.Record{p, C.Accepted{r}, at}, C.Fresh{C.Accepted{r}}, es} : C.Step<S, P, R, E>}
  {==}

def Laws.refuse_keeps_state(S, P, R, E, eq, dup_p, copy_p, dup_r, copy_r, decide, s, p, at, r, e):
  %Equal.sym(P & P, dup_p(p), (p, p), copy_p(p)) : {C.fresh(~S, ~P, ~R, ~E, ~dup_r, ~decide, _, s, at) == C.Note{C.Record{p, C.Refused{r}, at}, C.Fresh{C.Refused{r}}} : C.Step<S, P, R, E>}
  %Equal.sym(C.Decision<S, R, E>, decide(s, p), C.Refuse{r}, e) : {C.decided(~S, ~P, ~R, ~E, ~dup_r, _, p, at) == C.Note{C.Record{p, C.Refused{r}, at}, C.Fresh{C.Refused{r}}} : C.Step<S, P, R, E>}
  %Equal.sym(R & R, dup_r(r), (r, r), copy_r(r)) : {C.refused(S, P, R, E, _, p, at) == C.Note{C.Record{p, C.Refused{r}, at}, C.Fresh{C.Refused{r}}} : C.Step<S, P, R, E>}
  {==}

# retry_replays for any decision d, not only decide(s, p).
def retry.go(
  ~S: Type, ~P: Type, ~R: Type, ~E: Type, ~eq: P -> P -> Bool, ~refl: @-x: P -> {eq(x, x) == True{} : Bool},
  ~dup_p: P -> P & P, ~dup_r: R -> R & R, ~copy_r: @-x: R -> {dup_r(x) == (x, x) : R & R},
  ~decide: S -> P -> C.Decision<S, R, E>, d: C.Decision<S, R, E>, -s: S, -p: P, -at: U32, -later: U32
) -> {Laws.retried(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, C.decided(~S, ~P, ~R, ~E, ~dup_r, d, p, at), s, p, later)
      == Laws.again(S, P, R, E, C.decided(~S, ~P, ~R, ~E, ~dup_r, d, p, at)) : C.Step<S, P, R, E>}:
  match d:
    case C.Accept{s2, r, es}:
      %Equal.sym(R & R, dup_r(r), (r, r), copy_r(r)) : {Laws.retried(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, C.accepted(S, P, R, E, _, s2, p, at, es), s, p, later) == Laws.again(S, P, R, E, C.accepted(S, P, R, E, _, s2, p, at, es)) : C.Step<S, P, R, E>}
      %Equal.sym(Bool, eq(p, p), True{}, refl(p)) : {C.Keep{C.replayed(R, _, C.Accepted{r})} == C.Keep{C.Replayed{C.Accepted{r}}} : C.Step<S, P, R, E>}
      {==}
    case C.Refuse{r}:
      %Equal.sym(R & R, dup_r(r), (r, r), copy_r(r)) : {Laws.retried(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, C.refused(S, P, R, E, _, p, at), s, p, later) == Laws.again(S, P, R, E, C.refused(S, P, R, E, _, p, at)) : C.Step<S, P, R, E>}
      %Equal.sym(Bool, eq(p, p), True{}, refl(p)) : {C.Keep{C.replayed(R, _, C.Refused{r})} == C.Keep{C.Replayed{C.Refused{r}}} : C.Step<S, P, R, E>}
      {==}

def Laws.retry_replays(S, P, R, E, eq, refl, dup_p, copy_p, dup_r, copy_r, decide, s, p, at, later):
  %Equal.sym(P & P, dup_p(p), (p, p), copy_p(p)) : {Laws.retried(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, C.fresh(~S, ~P, ~R, ~E, ~dup_r, ~decide, _, s, at), s, p, later) == Laws.again(S, P, R, E, C.fresh(~S, ~P, ~R, ~E, ~dup_r, ~decide, _, s, at)) : C.Step<S, P, R, E>}
  retry.go(~S, ~P, ~R, ~E, ~eq, ~refl, ~dup_p, ~dup_r, ~copy_r, ~decide, decide(s, p), s, p, at, later)
