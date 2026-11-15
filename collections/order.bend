# Order: comparators for OMap, List.sort, and other templates that take ~cmp.
import Base

def string.fin(c: Cmp, rest: Cmp) -> Cmp:
  match c:
    case LT{}:
      LT{}
    case EQ{}:
      rest
    case GT{}:
      GT{}

# Strings in code-point order, a prefix before its extensions. String.order gives
# the same answers, but it rebuilds both strings on every call.
def string(a: String, b: String) -> Cmp:
  match a b:
    case SNil{} SNil{}:
      EQ{}
    case SNil{} SCon{h, t}:
      LT{}
    case SCon{h, t} SNil{}:
      GT{}
    case SCon{Chr{+x}, s} SCon{Chr{+y}, t}:
      string.fin(U32.cmp(x, y), string(s, t))
