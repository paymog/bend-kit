# Pure authorization policies: deny-overrides, default deny, intersection, and fail-closed missing context.
import Base

# What a policy may ask about one request. A `None` field is missing information:
# the caller did not authenticate a subject, load roles, or find the owner.
type Request is Data:
  Request{subject: Maybe<&2, String>, roles: Maybe<&2, List<&2, String>>, owner: Maybe<&2, String>, action: String, resource: String}

# A target answers Yes, No, or Unknown when it needs a missing field.
type Tri is Data:
  Yes{}
  No{}
  Unknown{}

type Target is Data:
  Everyone{}
  Nobody{}
  Action{name: String}
  Resource{name: String}
  Subject{name: String}
  Role{name: String}
  Owner{}
  AllOf{a: Target, b: Target}

# Abstain means that no rule applies. `granted` treats it as a denial.
type Decision is Data:
  Allow{}
  Deny{}
  Abstain{}

type Policy is Data:
  Permit{target: Target}
  Forbid{target: Target}
  DenyOverrides{a: Policy, b: Policy}
  Intersect{a: Policy, b: Policy}

def tri(b: Bool) -> Tri:
  match b:
    case True{}:
      Yes{}
    case False{}:
      No{}

def has(+name: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case x <> rest:
      String.eq(x, name) || has(name, rest)

def subject.is(name: String, s: Maybe<&2, String>) -> Tri:
  match s:
    case None{}:
      Unknown{}
    case Some{x}:
      tri(String.eq(x, name))

def role.is(name: String, r: Maybe<&2, List<&2, String>>) -> Tri:
  match r:
    case None{}:
      Unknown{}
    case Some{xs}:
      tri(has(name, xs))

def owner.is(x: String, o: Maybe<&2, String>) -> Tri:
  match o:
    case None{}:
      Unknown{}
    case Some{y}:
      tri(String.eq(x, y))

def owner.of(s: Maybe<&2, String>, o: Maybe<&2, String>) -> Tri:
  match s:
    case None{}:
      Unknown{}
    case Some{x}:
      owner.is(x, o)

# Kleene conjunction: No wins, then Unknown.
def all(a: Tri, b: Tri) -> Tri:
  match a:
    case No{}:
      No{}
    case Yes{}:
      b
    case Unknown{}:
      match b:
        case No{}:
          No{}
        case Yes{}:
          Unknown{}
        case Unknown{}:
          Unknown{}

def matches(t: Target, +req: Request) -> Tri:
  match t:
    case Everyone{}:
      Yes{}
    case Nobody{}:
      No{}
    case Action{name}:
      Request{s, r, o, action, resource} = req
      tri(String.eq(action, name))
    case Resource{name}:
      Request{s, r, o, action, resource} = req
      tri(String.eq(resource, name))
    case Subject{name}:
      Request{s, r, o, action, resource} = req
      subject.is(name, s)
    case Role{name}:
      Request{s, r, o, action, resource} = req
      role.is(name, r)
    case Owner{}:
      Request{s, r, o, action, resource} = req
      owner.of(s, o)
    case AllOf{a, b}:
      all(matches(a, req), matches(b, req))

# A permit grants only on Yes. Unknown cannot grant.
def permit(m: Tri) -> Decision:
  match m:
    case Yes{}:
      Allow{}
    case No{}:
      Abstain{}
    case Unknown{}:
      Abstain{}

# A forbid denies on Yes and on Unknown: it fails closed.
def forbid(m: Tri) -> Decision:
  match m:
    case Yes{}:
      Deny{}
    case No{}:
      Abstain{}
    case Unknown{}:
      Deny{}

# Deny wins, then Allow, then Abstain.
def deny_overrides(a: Decision, b: Decision) -> Decision:
  match a:
    case Deny{}:
      Deny{}
    case Abstain{}:
      b
    case Allow{}:
      match b:
        case Deny{}:
          Deny{}
        case Allow{}:
          Allow{}
        case Abstain{}:
          Allow{}

# Allow only when both allow. Deny wins over Abstain.
def intersect(a: Decision, b: Decision) -> Decision:
  match a:
    case Deny{}:
      Deny{}
    case Allow{}:
      b
    case Abstain{}:
      match b:
        case Deny{}:
          Deny{}
        case Allow{}:
          Abstain{}
        case Abstain{}:
          Abstain{}

def decide(p: Policy, +req: Request) -> Decision:
  match p:
    case Permit{t}:
      permit(matches(t, req))
    case Forbid{t}:
      forbid(matches(t, req))
    case DenyOverrides{a, b}:
      deny_overrides(decide(a, req), decide(b, req))
    case Intersect{a, b}:
      intersect(decide(a, req), decide(b, req))

def allowed(d: Decision) -> Bool:
  match d:
    case Allow{}:
      True{}
    case Deny{}:
      False{}
    case Abstain{}:
      False{}

# Default deny: only Allow grants.
def granted(p: Policy, +req: Request) -> Bool:
  allowed(decide(p, req))
