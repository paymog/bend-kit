import Base
import ./commands.bend as C

# Each law holds for every domain: any state, payload, result, and effect types, any payload
# comparison eq, any copies dup_p and dup_r, and any decide. `found` is the record that the store holds for the command's id.

# ---- a record exists for the id

# A duplicate: the payload equals the recorded one. Nothing is written, no effect is emitted,
# and the reply is the recorded outcome.
law duplicate_replays:
  for ~S: Type
  for ~P: Type
  for ~R: Type
  for ~E: Type
  for ~eq: P -> P -> Bool
  for ~dup_p: P -> P & P
  for ~dup_r: R -> R & R
  for ~decide: S -> P -> C.Decision<S, R, E>
  for -q: P
  for -o: C.Outcome<R>
  for -t: U32
  for -p: P
  for same: {eq(q, p) == True{} : Bool}
  for -s: S
  for -at: U32
  {C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, Some{C.Record{q, o, t}}, s, p, at) == C.Keep{C.Replayed{o}} : C.Step<S, P, R, E>}

# The id is reused with a different payload. It is rejected: nothing is written and no effect is emitted.
law conflict_rejected:
  for ~S: Type
  for ~P: Type
  for ~R: Type
  for ~E: Type
  for ~eq: P -> P -> Bool
  for ~dup_p: P -> P & P
  for ~dup_r: R -> R & R
  for ~decide: S -> P -> C.Decision<S, R, E>
  for -q: P
  for -o: C.Outcome<R>
  for -t: U32
  for -p: P
  for differ: {eq(q, p) == False{} : Bool}
  for -s: S
  for -at: U32
  {C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, Some{C.Record{q, o, t}}, s, p, at) == C.Keep{C.Conflict{}} : C.Step<S, P, R, E>}

# ---- no record for the id

# An accepted command writes the state that decide gave, its effects, and a record of exactly the result it replies.
law accept_recorded:
  for ~S: Type
  for ~P: Type
  for ~R: Type
  for ~E: Type
  for ~eq: P -> P -> Bool
  for ~dup_p: P -> P & P
  for ~copy_p: @-x: P -> {dup_p(x) == (x, x) : P & P}
  for ~dup_r: R -> R & R
  for ~copy_r: @-x: R -> {dup_r(x) == (x, x) : R & R}
  for ~decide: S -> P -> C.Decision<S, R, E>
  for -s: S
  for -p: P
  for -at: U32
  for -s2: S
  for -r: R
  for -es: List<E>
  for e: {decide(s, p) == C.Accept{s2, r, es} : C.Decision<S, R, E>}
  {C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, None{}, s, p, at) == C.Write{s2, C.Record{p, C.Accepted{r}, at}, C.Fresh{C.Accepted{r}}, es} : C.Step<S, P, R, E>}

# A refused command writes only its record: the domain state is kept and no effect is emitted.
# Its result is recorded, so a retry gets the same answer.
law refuse_keeps_state:
  for ~S: Type
  for ~P: Type
  for ~R: Type
  for ~E: Type
  for ~eq: P -> P -> Bool
  for ~dup_p: P -> P & P
  for ~copy_p: @-x: P -> {dup_p(x) == (x, x) : P & P}
  for ~dup_r: R -> R & R
  for ~copy_r: @-x: R -> {dup_r(x) == (x, x) : R & R}
  for ~decide: S -> P -> C.Decision<S, R, E>
  for -s: S
  for -p: P
  for -at: U32
  for -r: R
  for e: {decide(s, p) == C.Refuse{r} : C.Decision<S, R, E>}
  {C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, None{}, s, p, at) == C.Note{C.Record{p, C.Refused{r}, at}, C.Fresh{C.Refused{r}}} : C.Step<S, P, R, E>}

# ---- a retry after the first commit

# The step that a retry runs against what w committed: its record, and its state or the kept state s.
def retried(
  ~S: Type, ~P: Type, ~R: Type, ~E: Type, ~eq: P -> P -> Bool, ~dup_p: P -> P & P, ~dup_r: R -> R & R,
  ~decide: S -> P -> C.Decision<S, R, E>, w: C.Step<S, P, R, E>, s: S, p: P, at: U32
) -> C.Step<S, P, R, E>:
  match w:
    case C.Write{s2, rec, reply, es}:
      C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, Some{rec}, s2, p, at)
    case C.Note{rec, reply}:
      C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, Some{rec}, s, p, at)
    case C.Keep{reply}:
      C.Keep{reply}

# A replay of w's reply that writes nothing.
def again(-S: Type, -P: Type, -R: Type, -E: Type, w: C.Step<S, P, R, E>) -> C.Step<S, P, R, E>:
  match w:
    case C.Write{s, C.Record{q, o, t}, reply, es}:
      C.Keep{C.Replayed{o}}
    case C.Note{C.Record{q, o, t}, reply}:
      C.Keep{C.Replayed{o}}
    case C.Keep{reply}:
      C.Keep{reply}

# When eq is reflexive and dup_p and dup_r copy, a retry with the same payload after the first commit
# writes nothing, emits nothing, and replays the first outcome, at any later time.
law retry_replays:
  for ~S: Type
  for ~P: Type
  for ~R: Type
  for ~E: Type
  for ~eq: P -> P -> Bool
  for ~refl: @-x: P -> {eq(x, x) == True{} : Bool}
  for ~dup_p: P -> P & P
  for ~copy_p: @-x: P -> {dup_p(x) == (x, x) : P & P}
  for ~dup_r: R -> R & R
  for ~copy_r: @-x: R -> {dup_r(x) == (x, x) : R & R}
  for ~decide: S -> P -> C.Decision<S, R, E>
  for s: S
  for p: P
  for -at: U32
  for -later: U32
  {retried(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, None{}, s, p, at), s, p, later)
   == again(S, P, R, E, C.step(~S, ~P, ~R, ~E, ~eq, ~dup_p, ~dup_r, ~decide, None{}, s, p, at)) : C.Step<S, P, R, E>}
