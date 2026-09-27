import Base
import ../hpack.bend as Hp
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def text.sum(s: String, +sum: U32) -> U32:
  match s:
    case SNil{}:
      sum
    case SCon{Chr{octet}, tail}:
      text.sum(tail, (sum + octet : U32))

def fields.sum(xs: List<&2, Hp.Field>, +sum: U32) -> U32:
  match xs:
    case Nil{}:
      sum
    case Con{Hp.Field{name, value, mode}, tail}:
      fields.sum(tail, text.sum(value, text.sum(name, sum)))

def with_decoded(-R: Type, r: Hp.State & List<&2, Hp.Field>, k: Hp.State -> List<&2, Hp.Field> -> R) -> R:
  (state, fields) = r
  k(state, fields)

def run(n: Nat, state: Hp.State, +sum: U32) -> Maybe<&1, U32>:
  match n:
    case 0n:
      Some{sum}
    case 1n+p:
      Maybe.bind(&1, Hp.State & List<&2, Hp.Field>, U32,
        Hp.decode(Bytes.from_string("\u{82}\u{86}\u{84}A\u{0f}www.example.com"), state), pair =>
          with_decoded(Maybe<&1, U32>, pair, next => fields =>
            run(p, next, fields.sum(fields, sum))))

def report(m: Maybe<&1, U32>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "HPACK decode failed")
    case Some{sum}:
      IO.print(U32.show(sum))

def main() -> IO(Unit):
  report(run(1000n, Hp.new(4096), 0))
