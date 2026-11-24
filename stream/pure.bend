# Pure chunk validation and bounded-transfer read decisions.
import Base

# Internal pure decisions, separated from the trusted effects.
type ReadAction is Data:
  End{}
  Over{}
  Forward{}

def chunk.valid(+chunk: U32) -> Bool:
  U32.is_ge(chunk, 1) && U32.is_le(chunk, 1048576)

# The one-byte probe is only requested after the entire cap was forwarded.
def request(+chunk: U32, +remaining: U32) -> U32:
  match remaining:
    case 0:
      1
    case _:
      U32.min(chunk, remaining)

def read.action.flags(zero: Bool, probe: Bool) -> ReadAction:
  match zero:
    case True{}:
      End{}
    case False{}:
      match probe:
        case True{}:
          Over{}
        case False{}:
          Forward{}

def read.action(len: U32, remaining: U32) -> ReadAction:
  read.action.flags(U32.is_zero(len), U32.is_zero(remaining))
