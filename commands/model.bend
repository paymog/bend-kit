import Base

type Outcome<-R: Type> is Type:
  Accepted{result: R}
  Refused{result: R}

# What the store keeps for one command id: its payload, its outcome, and when it was recorded.
type Record<-P: Type, -R: Type> is Type:
  Record{payload: P, outcome: Outcome<R>, at: U32}

type Reply<-R: Type> is Type:
  Fresh{outcome: Outcome<R>}
  Replayed{outcome: Outcome<R>}
  Conflict{}

# The domain's answer to a new command.
type Decision<-S: Type, -R: Type, -E: Type> is Type:
  Accept{state: S, result: R, effects: List<E>}
  Refuse{result: R}

# Write: commit the state, the record, and the effects together. Note: commit only the record. Keep: write nothing.
type Step<-S: Type, -P: Type, -R: Type, -E: Type> is Type:
  Write{state: S, record: Record<P, R>, reply: Reply<R>, effects: List<E>}
  Note{record: Record<P, R>, reply: Reply<R>}
  Keep{reply: Reply<R>}

def accepted(-S: Type, -P: Type, -R: Type, -E: Type, rr: R & R, s2: S, p: P, at: U32, es: List<E>) -> Step<S, P, R, E>:
  (r, r2) = rr
  Write{s2, Record{p, Accepted{r}, at}, Fresh{Accepted{r2}}, es}

def refused(-S: Type, -P: Type, -R: Type, -E: Type, rr: R & R, p: P, at: U32) -> Step<S, P, R, E>:
  (r, r2) = rr
  Note{Record{p, Refused{r}, at}, Fresh{Refused{r2}}}

def decided(~S: Type, ~P: Type, ~R: Type, ~E: Type, ~dup_r: R -> R & R, d: Decision<S, R, E>, p: P, at: U32) -> Step<S, P, R, E>:
  match d:
    case Accept{s2, r, es}:
      accepted(S, P, R, E, dup_r(r), s2, p, at, es)
    case Refuse{r}:
      refused(S, P, R, E, dup_r(r), p, at)

def fresh(
  ~S: Type, ~P: Type, ~R: Type, ~E: Type, ~dup_r: R -> R & R, ~decide: S -> P -> Decision<S, R, E>,
  pp: P & P, s: S, at: U32
) -> Step<S, P, R, E>:
  (p, p2) = pp
  decided(~S, ~P, ~R, ~E, ~dup_r, decide(s, p), p2, at)

def replayed(-R: Type, same: Bool, o: Outcome<R>) -> Reply<R>:
  match same:
    case True{}:
      Replayed{o}
    case False{}:
      Conflict{}

# One command, given the record that the store holds for its id and the domain state s.
# dup_p and dup_r copy a payload and a result: a new command's payload goes to decide and to the record.
def step(
  ~S: Type, ~P: Type, ~R: Type, ~E: Type, ~eq: P -> P -> Bool, ~dup_p: P -> P & P, ~dup_r: R -> R & R,
  ~decide: S -> P -> Decision<S, R, E>, found: Maybe<Record<P, R>>, s: S, p: P, at: U32
) -> Step<S, P, R, E>:
  match found:
    case None{}:
      fresh(~S, ~P, ~R, ~E, ~dup_r, ~decide, dup_p(p), s, at)
    case Some{Record{q, o, t}}:
      Keep{replayed(R, eq(q, p), o)}
