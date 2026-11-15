import Base
import ./authz.bend as Az

# `less` is missing information that `more` has, and the two agree on the rest.
def Known(-A: Data, less: Maybe<&2, A>, more: Maybe<&2, A>) -> Data:
  match less:
    case None{}:
      Unit
    case Some{x}:
      {more == Some{x} : Maybe<&2, A>}

# Deny overrides: an explicit deny on either side denies.
law deny_overrides_left:
  for p: Az.Policy
  for q: Az.Policy
  for r: Az.Request
  for e: {Az.decide(p, r) == Az.Deny{} : Az.Decision}
  {Az.decide(Az.DenyOverrides{p, q}, r) == Az.Deny{} : Az.Decision}

law deny_overrides_right:
  for p: Az.Policy
  for q: Az.Policy
  for r: Az.Request
  for e: {Az.decide(q, r) == Az.Deny{} : Az.Decision}
  {Az.decide(Az.DenyOverrides{p, q}, r) == Az.Deny{} : Az.Decision}

# A deny survives an intersection.
law deny_intersect:
  for p: Az.Policy
  for q: Az.Policy
  for r: Az.Request
  for e: {Az.decide(p, r) == Az.Deny{} : Az.Decision}
  {Az.decide(Az.Intersect{p, q}, r) == Az.Deny{} : Az.Decision}

# Default deny: when no rule applies, nothing is granted.
law default_deny:
  for p: Az.Policy
  for r: Az.Request
  for e: {Az.decide(p, r) == Az.Abstain{} : Az.Decision}
  {Az.granted(p, r) == False{} : Bool}

# An intersection grants exactly what both policies grant.
law intersect_grants:
  for p: Az.Policy
  for q: Az.Policy
  for r: Az.Request
  {Az.granted(Az.Intersect{p, q}, r) == Bool.and(Az.granted(p, r), Az.granted(q, r)) : Bool}

# A restriction cannot grant more than the policy it restricts.
law restrict_narrows:
  for p: Az.Policy
  for q: Az.Policy
  for r: Az.Request
  for g: {Az.granted(Az.Intersect{p, q}, r) == True{} : Bool}
  {Az.granted(p, r) == True{} : Bool}

# Adding a forbid rule cannot grant more.
law forbid_narrows:
  for p: Az.Policy
  for t: Az.Target
  for r: Az.Request
  for g: {Az.granted(Az.DenyOverrides{p, Az.Forbid{t}}, r) == True{} : Bool}
  {Az.granted(p, r) == True{} : Bool}

# Missing information never grants what the full information would not.
law missing_never_grants:
  for p: Az.Policy
  for s1: Maybe<&2, String>
  for s2: Maybe<&2, String>
  for es: Known(String, s1, s2)
  for r1: Maybe<&2, List<&2, String>>
  for r2: Maybe<&2, List<&2, String>>
  for er: Known(List<&2, String>, r1, r2)
  for o1: Maybe<&2, String>
  for o2: Maybe<&2, String>
  for eo: Known(String, o1, o2)
  for a: String
  for x: String
  for g: {Az.granted(p, Az.Request{s1, r1, o1, a, x}) == True{} : Bool}
  {Az.granted(p, Az.Request{s2, r2, o2, a, x}) == True{} : Bool}

# A forbid whose target needs missing information denies.
law forbid_unknown_denies:
  for p: Az.Policy
  for t: Az.Target
  for r: Az.Request
  for e: {Az.matches(t, r) == Az.Unknown{} : Az.Tri}
  {Az.decide(Az.DenyOverrides{p, Az.Forbid{t}}, r) == Az.Deny{} : Az.Decision}

# DenyOverrides is a commutative, associative, idempotent monoid with unit Permit{Nobody}.
law deny_overrides_comm:
  for p: Az.Policy
  for q: Az.Policy
  for r: Az.Request
  {Az.decide(Az.DenyOverrides{p, q}, r) == Az.decide(Az.DenyOverrides{q, p}, r) : Az.Decision}

law deny_overrides_assoc:
  for p: Az.Policy
  for q: Az.Policy
  for s: Az.Policy
  for r: Az.Request
  {Az.decide(Az.DenyOverrides{Az.DenyOverrides{p, q}, s}, r) == Az.decide(Az.DenyOverrides{p, Az.DenyOverrides{q, s}}, r) : Az.Decision}

law deny_overrides_idem:
  for p: Az.Policy
  for r: Az.Request
  {Az.decide(Az.DenyOverrides{p, p}, r) == Az.decide(p, r) : Az.Decision}

law deny_overrides_unit:
  for p: Az.Policy
  for r: Az.Request
  {Az.decide(Az.DenyOverrides{Az.Permit{Az.Nobody{}}, p}, r) == Az.decide(p, r) : Az.Decision}

# Intersect is a commutative, associative, idempotent monoid with unit Permit{Everyone}.
law intersect_comm:
  for p: Az.Policy
  for q: Az.Policy
  for r: Az.Request
  {Az.decide(Az.Intersect{p, q}, r) == Az.decide(Az.Intersect{q, p}, r) : Az.Decision}

law intersect_assoc:
  for p: Az.Policy
  for q: Az.Policy
  for s: Az.Policy
  for r: Az.Request
  {Az.decide(Az.Intersect{Az.Intersect{p, q}, s}, r) == Az.decide(Az.Intersect{p, Az.Intersect{q, s}}, r) : Az.Decision}

law intersect_idem:
  for p: Az.Policy
  for r: Az.Request
  {Az.decide(Az.Intersect{p, p}, r) == Az.decide(p, r) : Az.Decision}

law intersect_unit:
  for p: Az.Policy
  for r: Az.Request
  {Az.decide(Az.Intersect{Az.Permit{Az.Everyone{}}, p}, r) == Az.decide(p, r) : Az.Decision}
