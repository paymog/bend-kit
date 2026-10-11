import Base
import bend-mathlib@0.7.2.0/bool.bend as MBool
import ./authz.bend as Az
import ./LAWS.bend as Laws

# Grant order: Deny below Abstain below Allow.
def DLe(a: Az.Decision, b: Az.Decision) -> Type:
  match a:
    case Az.Deny{}:
      Unit
    case Az.Abstain{}:
      match b:
        case Az.Deny{}:
          Empty
        case Az.Abstain{}:
          Unit
        case Az.Allow{}:
          Unit
    case Az.Allow{}:
      match b:
        case Az.Allow{}:
          Unit
        case Az.Deny{}:
          Empty
        case Az.Abstain{}:
          Empty

# Information order: Unknown below Yes and below No.
def ILe(a: Az.Tri, b: Az.Tri) -> Type:
  match a:
    case Az.Unknown{}:
      Unit
    case Az.Yes{}:
      match b:
        case Az.Yes{}:
          Unit
        case Az.No{}:
          Empty
        case Az.Unknown{}:
          Empty
    case Az.No{}:
      match b:
        case Az.No{}:
          Unit
        case Az.Yes{}:
          Empty
        case Az.Unknown{}:
          Empty

def ile_refl(m: Az.Tri) -> ILe(m, m):
  match m:
    case Az.Yes{}:
      Unit{}
    case Az.No{}:
      Unit{}
    case Az.Unknown{}:
      Unit{}

def all_mono(a1: Az.Tri, b1: Az.Tri, b2: Az.Tri, a2: Az.Tri, ha: ILe(a1, a2), hb: ILe(b1, b2)) -> ILe(Az.all(a1, b1), Az.all(a2, b2)):
  match a1:
    case Az.No{}:
      match a2:
        case Az.No{}:
          Unit{}
        case Az.Yes{}:
          match ha:
        case Az.Unknown{}:
          match ha:
    case Az.Yes{}:
      match a2:
        case Az.Yes{}:
          hb
        case Az.No{}:
          match ha:
        case Az.Unknown{}:
          match ha:
    case Az.Unknown{}:
      match b1:
        case Az.Yes{}:
          Unit{}
        case Az.Unknown{}:
          Unit{}
        case Az.No{}:
          match b2:
            case Az.No{}:
              match a2:
                case Az.No{}:
                  Unit{}
                case Az.Yes{}:
                  Unit{}
                case Az.Unknown{}:
                  Unit{}
            case Az.Yes{}:
              match hb:
            case Az.Unknown{}:
              match hb:

def subject_mono(+name: String, s1: Maybe<&2, String>, -s2: Maybe<&2, String>, es: Laws.Known(String, s1, s2)) -> ILe(Az.subject.is(name, s1), Az.subject.is(name, s2)):
  match s1:
    case None{}:
      Unit{}
    case Some{+x}:
      %Equal.sym(Maybe<&2, String>, s2, Some{x}, es) : ILe(Az.subject.is(name, Some{x}), Az.subject.is(name, _))
      ile_refl(Az.subject.is(name, Some{x}))

def role_mono(+name: String, r1: Maybe<&2, List<&2, String>>, -r2: Maybe<&2, List<&2, String>>, er: Laws.Known(List<&2, String>, r1, r2)) -> ILe(Az.role.is(name, r1), Az.role.is(name, r2)):
  match r1:
    case None{}:
      Unit{}
    case Some{+xs}:
      %Equal.sym(Maybe<&2, List<&2, String>>, r2, Some{xs}, er) : ILe(Az.role.is(name, Some{xs}), Az.role.is(name, _))
      ile_refl(Az.role.is(name, Some{xs}))

def owner_is_mono(+x: String, o1: Maybe<&2, String>, -o2: Maybe<&2, String>, eo: Laws.Known(String, o1, o2)) -> ILe(Az.owner.is(x, o1), Az.owner.is(x, o2)):
  match o1:
    case None{}:
      Unit{}
    case Some{+y}:
      %Equal.sym(Maybe<&2, String>, o2, Some{y}, eo) : ILe(Az.owner.is(x, Some{y}), Az.owner.is(x, _))
      ile_refl(Az.owner.is(x, Some{y}))

def owner_mono(s1: Maybe<&2, String>, -s2: Maybe<&2, String>, es: Laws.Known(String, s1, s2), o1: Maybe<&2, String>, -o2: Maybe<&2, String>, eo: Laws.Known(String, o1, o2)) -> ILe(Az.owner.of(s1, o1), Az.owner.of(s2, o2)):
  match s1:
    case None{}:
      Unit{}
    case Some{+x}:
      %Equal.sym(Maybe<&2, String>, s2, Some{x}, es) : ILe(Az.owner.of(Some{x}, o1), Az.owner.of(_, o2))
      owner_is_mono(x, o1, o2, eo)

def target_mono(t: Az.Target,
  +s1: Maybe<&2, String>, +s2: Maybe<&2, String>, +es: Laws.Known(String, s1, s2),
  +r1: Maybe<&2, List<&2, String>>, +r2: Maybe<&2, List<&2, String>>, +er: Laws.Known(List<&2, String>, r1, r2),
  +o1: Maybe<&2, String>, +o2: Maybe<&2, String>, +eo: Laws.Known(String, o1, o2), +act: String, +res: String
) -> ILe(Az.matches(t, Az.Request{s1, r1, o1, act, res}), Az.matches(t, Az.Request{s2, r2, o2, act, res})):
  match t:
    case Az.Everyone{}:
      Unit{}
    case Az.Nobody{}:
      Unit{}
    case Az.Action{name}:
      ile_refl(Az.tri(String.eq(act, name)))
    case Az.Resource{name}:
      ile_refl(Az.tri(String.eq(res, name)))
    case Az.Subject{name}:
      subject_mono(name, s1, s2, es)
    case Az.Role{name}:
      role_mono(name, r1, r2, er)
    case Az.Owner{}:
      owner_mono(s1, s2, es, o1, o2, eo)
    case Az.AllOf{+a, +b}:
      +q1 = {Az.Request{s1, r1, o1, act, res} : Az.Request}
      +q2 = {Az.Request{s2, r2, o2, act, res} : Az.Request}
      all_mono(Az.matches(a, q1), Az.matches(b, q1), Az.matches(b, q2), Az.matches(a, q2),
        target_mono(a, s1, s2, es, r1, r2, er, o1, o2, eo, act, res),
        target_mono(b, s1, s2, es, r1, r2, er, o1, o2, eo, act, res))

def permit_mono(m1: Az.Tri, m2: Az.Tri, h: ILe(m1, m2)) -> DLe(Az.permit(m1), Az.permit(m2)):
  match m1:
    case Az.Yes{}:
      match m2:
        case Az.Yes{}:
          Unit{}
        case Az.No{}:
          match h:
        case Az.Unknown{}:
          match h:
    case Az.No{}:
      match m2:
        case Az.No{}:
          Unit{}
        case Az.Yes{}:
          match h:
        case Az.Unknown{}:
          match h:
    case Az.Unknown{}:
      match m2:
        case Az.Yes{}:
          Unit{}
        case Az.No{}:
          Unit{}
        case Az.Unknown{}:
          Unit{}

def forbid_mono(m1: Az.Tri, m2: Az.Tri, h: ILe(m1, m2)) -> DLe(Az.forbid(m1), Az.forbid(m2)):
  match m1:
    case Az.Yes{}:
      Unit{}
    case Az.Unknown{}:
      Unit{}
    case Az.No{}:
      match m2:
        case Az.No{}:
          Unit{}
        case Az.Yes{}:
          match h:
        case Az.Unknown{}:
          match h:

def dor_mono(a1: Az.Decision, a2: Az.Decision, b1: Az.Decision, b2: Az.Decision, ha: DLe(a1, a2), hb: DLe(b1, b2)) -> DLe(Az.deny_overrides(a1, b1), Az.deny_overrides(a2, b2)):
  match a1:
    case Az.Deny{}:
      Unit{}
    case Az.Abstain{}:
      match a2:
        case Az.Deny{}:
          match ha:
        case Az.Abstain{}:
          hb
        case Az.Allow{}:
          match b1:
            case Az.Deny{}:
              Unit{}
            case Az.Abstain{}:
              match b2:
                case Az.Deny{}:
                  match hb:
                case Az.Abstain{}:
                  Unit{}
                case Az.Allow{}:
                  Unit{}
            case Az.Allow{}:
              match b2:
                case Az.Allow{}:
                  Unit{}
                case Az.Deny{}:
                  match hb:
                case Az.Abstain{}:
                  match hb:
    case Az.Allow{}:
      match a2:
        case Az.Deny{}:
          match ha:
        case Az.Abstain{}:
          match ha:
        case Az.Allow{}:
          match b1:
            case Az.Deny{}:
              Unit{}
            case Az.Abstain{}:
              match b2:
                case Az.Deny{}:
                  match hb:
                case Az.Abstain{}:
                  Unit{}
                case Az.Allow{}:
                  Unit{}
            case Az.Allow{}:
              match b2:
                case Az.Allow{}:
                  Unit{}
                case Az.Deny{}:
                  match hb:
                case Az.Abstain{}:
                  match hb:

def int_mono(a1: Az.Decision, a2: Az.Decision, b1: Az.Decision, b2: Az.Decision, ha: DLe(a1, a2), hb: DLe(b1, b2)) -> DLe(Az.intersect(a1, b1), Az.intersect(a2, b2)):
  match a1:
    case Az.Deny{}:
      Unit{}
    case Az.Allow{}:
      match a2:
        case Az.Allow{}:
          hb
        case Az.Deny{}:
          match ha:
        case Az.Abstain{}:
          match ha:
    case Az.Abstain{}:
      match a2:
        case Az.Deny{}:
          match ha:
        case Az.Abstain{}:
          match b1:
            case Az.Deny{}:
              Unit{}
            case Az.Abstain{}:
              match b2:
                case Az.Deny{}:
                  match hb:
                case Az.Abstain{}:
                  Unit{}
                case Az.Allow{}:
                  Unit{}
            case Az.Allow{}:
              match b2:
                case Az.Allow{}:
                  Unit{}
                case Az.Deny{}:
                  match hb:
                case Az.Abstain{}:
                  match hb:
        case Az.Allow{}:
          match b1:
            case Az.Deny{}:
              Unit{}
            case Az.Abstain{}:
              hb
            case Az.Allow{}:
              match b2:
                case Az.Allow{}:
                  Unit{}
                case Az.Deny{}:
                  match hb:
                case Az.Abstain{}:
                  match hb:

def decide_mono(p: Az.Policy,
  +s1: Maybe<&2, String>, +s2: Maybe<&2, String>, +es: Laws.Known(String, s1, s2),
  +r1: Maybe<&2, List<&2, String>>, +r2: Maybe<&2, List<&2, String>>, +er: Laws.Known(List<&2, String>, r1, r2),
  +o1: Maybe<&2, String>, +o2: Maybe<&2, String>, +eo: Laws.Known(String, o1, o2), +act: String, +res: String
) -> DLe(Az.decide(p, Az.Request{s1, r1, o1, act, res}), Az.decide(p, Az.Request{s2, r2, o2, act, res})):
  match p:
    case Az.Permit{+t}:
      +q1 = {Az.Request{s1, r1, o1, act, res} : Az.Request}
      +q2 = {Az.Request{s2, r2, o2, act, res} : Az.Request}
      permit_mono(Az.matches(t, q1), Az.matches(t, q2), target_mono(t, s1, s2, es, r1, r2, er, o1, o2, eo, act, res))
    case Az.Forbid{+t}:
      +q1 = {Az.Request{s1, r1, o1, act, res} : Az.Request}
      +q2 = {Az.Request{s2, r2, o2, act, res} : Az.Request}
      forbid_mono(Az.matches(t, q1), Az.matches(t, q2), target_mono(t, s1, s2, es, r1, r2, er, o1, o2, eo, act, res))
    case Az.DenyOverrides{+a, +b}:
      +q1 = {Az.Request{s1, r1, o1, act, res} : Az.Request}
      +q2 = {Az.Request{s2, r2, o2, act, res} : Az.Request}
      dor_mono(Az.decide(a, q1), Az.decide(a, q2), Az.decide(b, q1), Az.decide(b, q2),
        decide_mono(a, s1, s2, es, r1, r2, er, o1, o2, eo, act, res),
        decide_mono(b, s1, s2, es, r1, r2, er, o1, o2, eo, act, res))
    case Az.Intersect{+a, +b}:
      +q1 = {Az.Request{s1, r1, o1, act, res} : Az.Request}
      +q2 = {Az.Request{s2, r2, o2, act, res} : Az.Request}
      int_mono(Az.decide(a, q1), Az.decide(a, q2), Az.decide(b, q1), Az.decide(b, q2),
        decide_mono(a, s1, s2, es, r1, r2, er, o1, o2, eo, act, res),
        decide_mono(b, s1, s2, es, r1, r2, er, o1, o2, eo, act, res))

def grant_mono(d1: Az.Decision, d2: Az.Decision, h: DLe(d1, d2), g: {Az.allowed(d1) == True{} : Bool}) -> {Az.allowed(d2) == True{} : Bool}:
  match d1:
    case Az.Allow{}:
      match d2:
        case Az.Allow{}:
          {==}
        case Az.Deny{}:
          match h:
        case Az.Abstain{}:
          match h:
    case Az.Deny{}:
      Empty.absurd({Az.allowed(d2) == True{} : Bool}, MBool.false_ne_true()(g))
    case Az.Abstain{}:
      Empty.absurd({Az.allowed(d2) == True{} : Bool}, MBool.false_ne_true()(g))

def Laws.missing_never_grants(p, s1, s2, es, r1, r2, er, o1, o2, eo, a, x, g):
  +p = p
  +s1 = s1
  +s2 = s2
  +r1 = r1
  +r2 = r2
  +o1 = o1
  +o2 = o2
  +a = a
  +x = x
  grant_mono(Az.decide(p, Az.Request{s1, r1, o1, a, x}), Az.decide(p, Az.Request{s2, r2, o2, a, x}), decide_mono(p, s1, s2, es, r1, r2, er, o1, o2, eo, a, x), g)

def dor_deny_right(a: Az.Decision) -> {Az.deny_overrides(a, Az.Deny{}) == Az.Deny{} : Az.Decision}:
  match a:
    case Az.Deny{}:
      {==}
    case Az.Abstain{}:
      {==}
    case Az.Allow{}:
      {==}

def Laws.deny_overrides_left(p, q, r, e):
  %Equal.sym(Az.Decision, Az.decide(p, r), Az.Deny{}, e) : {Az.deny_overrides(_, Az.decide(q, r)) == Az.Deny{} : Az.Decision}
  {==}

def Laws.deny_overrides_right(p, q, r, e):
  +r = r
  %Equal.sym(Az.Decision, Az.decide(q, r), Az.Deny{}, e) : {Az.deny_overrides(Az.decide(p, r), _) == Az.Deny{} : Az.Decision}
  dor_deny_right(Az.decide(p, r))

def Laws.deny_intersect(p, q, r, e):
  %Equal.sym(Az.Decision, Az.decide(p, r), Az.Deny{}, e) : {Az.intersect(_, Az.decide(q, r)) == Az.Deny{} : Az.Decision}
  {==}

def Laws.default_deny(p, r, e):
  %Equal.sym(Az.Decision, Az.decide(p, r), Az.Abstain{}, e) : {Az.allowed(_) == False{} : Bool}
  {==}

def int_grants(a: Az.Decision, b: Az.Decision) -> {Az.allowed(Az.intersect(a, b)) == Bool.and(Az.allowed(a), Az.allowed(b)) : Bool}:
  match a:
    case Az.Deny{}:
      {==}
    case Az.Allow{}:
      {==}
    case Az.Abstain{}:
      match b:
        case Az.Deny{}:
          {==}
        case Az.Allow{}:
          {==}
        case Az.Abstain{}:
          {==}

def Laws.intersect_grants(p, q, r):
  +r = r
  int_grants(Az.decide(p, r), Az.decide(q, r))

def int_narrows(a: Az.Decision, b: Az.Decision, g: {Az.allowed(Az.intersect(a, b)) == True{} : Bool}) -> {Az.allowed(a) == True{} : Bool}:
  match a:
    case Az.Allow{}:
      {==}
    case Az.Deny{}:
      Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))
    case Az.Abstain{}:
      match b:
        case Az.Deny{}:
          Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))
        case Az.Allow{}:
          Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))
        case Az.Abstain{}:
          Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))

def Laws.restrict_narrows(p, q, r, g):
  +r = r
  int_narrows(Az.decide(p, r), Az.decide(q, r), g)

def forbid_narrows.go(a: Az.Decision, m: Az.Tri, g: {Az.allowed(Az.deny_overrides(a, Az.forbid(m))) == True{} : Bool}) -> {Az.allowed(a) == True{} : Bool}:
  match a:
    case Az.Allow{}:
      {==}
    case Az.Deny{}:
      Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))
    case Az.Abstain{}:
      match m:
        case Az.Yes{}:
          Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))
        case Az.No{}:
          Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))
        case Az.Unknown{}:
          Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(g))

def Laws.forbid_narrows(p, t, r, g):
  +r = r
  forbid_narrows.go(Az.decide(p, r), Az.matches(t, r), g)

def Laws.forbid_unknown_denies(p, t, r, e):
  +r = r
  %Equal.sym(Az.Tri, Az.matches(t, r), Az.Unknown{}, e) : {Az.deny_overrides(Az.decide(p, r), Az.forbid(_)) == Az.Deny{} : Az.Decision}
  dor_deny_right(Az.decide(p, r))

def dor_comm(a: Az.Decision, b: Az.Decision) -> {Az.deny_overrides(a, b) == Az.deny_overrides(b, a) : Az.Decision}:
  match a b:
    case Az.Deny{} Az.Deny{}:
      {==}
    case Az.Deny{} Az.Abstain{}:
      {==}
    case Az.Deny{} Az.Allow{}:
      {==}
    case Az.Abstain{} Az.Deny{}:
      {==}
    case Az.Abstain{} Az.Abstain{}:
      {==}
    case Az.Abstain{} Az.Allow{}:
      {==}
    case Az.Allow{} Az.Deny{}:
      {==}
    case Az.Allow{} Az.Abstain{}:
      {==}
    case Az.Allow{} Az.Allow{}:
      {==}

def Laws.deny_overrides_comm(p, q, r):
  +r = r
  dor_comm(Az.decide(p, r), Az.decide(q, r))

def dor_assoc(a: Az.Decision, b: Az.Decision, c: Az.Decision) -> {Az.deny_overrides(Az.deny_overrides(a, b), c) == Az.deny_overrides(a, Az.deny_overrides(b, c)) : Az.Decision}:
  match a:
    case Az.Deny{}:
      {==}
    case Az.Abstain{}:
      {==}
    case Az.Allow{}:
      match b:
        case Az.Deny{}:
          {==}
        case Az.Abstain{}:
          {==}
        case Az.Allow{}:
          match c:
            case Az.Deny{}:
              {==}
            case Az.Abstain{}:
              {==}
            case Az.Allow{}:
              {==}

def Laws.deny_overrides_assoc(p, q, s, r):
  +r = r
  dor_assoc(Az.decide(p, r), Az.decide(q, r), Az.decide(s, r))

def dor_idem(a: Az.Decision) -> {Az.deny_overrides(a, a) == a : Az.Decision}:
  match a:
    case Az.Deny{}:
      {==}
    case Az.Abstain{}:
      {==}
    case Az.Allow{}:
      {==}

def Laws.deny_overrides_idem(p, r):
  dor_idem(Az.decide(p, r))

def Laws.deny_overrides_unit(p, r):
  {==}

def int_comm(a: Az.Decision, b: Az.Decision) -> {Az.intersect(a, b) == Az.intersect(b, a) : Az.Decision}:
  match a b:
    case Az.Deny{} Az.Deny{}:
      {==}
    case Az.Deny{} Az.Abstain{}:
      {==}
    case Az.Deny{} Az.Allow{}:
      {==}
    case Az.Abstain{} Az.Deny{}:
      {==}
    case Az.Abstain{} Az.Abstain{}:
      {==}
    case Az.Abstain{} Az.Allow{}:
      {==}
    case Az.Allow{} Az.Deny{}:
      {==}
    case Az.Allow{} Az.Abstain{}:
      {==}
    case Az.Allow{} Az.Allow{}:
      {==}

def Laws.intersect_comm(p, q, r):
  +r = r
  int_comm(Az.decide(p, r), Az.decide(q, r))

def int_assoc(a: Az.Decision, b: Az.Decision, c: Az.Decision) -> {Az.intersect(Az.intersect(a, b), c) == Az.intersect(a, Az.intersect(b, c)) : Az.Decision}:
  match a:
    case Az.Deny{}:
      {==}
    case Az.Allow{}:
      {==}
    case Az.Abstain{}:
      match b:
        case Az.Deny{}:
          {==}
        case Az.Allow{}:
          match c:
            case Az.Deny{}:
              {==}
            case Az.Abstain{}:
              {==}
            case Az.Allow{}:
              {==}
        case Az.Abstain{}:
          match c:
            case Az.Deny{}:
              {==}
            case Az.Abstain{}:
              {==}
            case Az.Allow{}:
              {==}

def Laws.intersect_assoc(p, q, s, r):
  +r = r
  int_assoc(Az.decide(p, r), Az.decide(q, r), Az.decide(s, r))

def int_idem(a: Az.Decision) -> {Az.intersect(a, a) == a : Az.Decision}:
  match a:
    case Az.Deny{}:
      {==}
    case Az.Abstain{}:
      {==}
    case Az.Allow{}:
      {==}

def Laws.intersect_idem(p, r):
  int_idem(Az.decide(p, r))

def Laws.intersect_unit(p, r):
  {==}
