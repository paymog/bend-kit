import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import ../protobuf.bend as P
import ./schema.bend as S

def error(e: P.Error) -> IO(Unit):
  match e:
    case P.Incomplete{}:
      IO.print("incomplete")
    case P.Malformed{}:
      IO.print("malformed")
    case P.Limit{}:
      IO.print("limit")
    case P.InvalidUtf8{}:
      IO.print("utf8")

def encoded(r: Result<&2, &1, P.Error, B.Bytes>) -> IO(Unit):
  match r:
    case Fail{e}:
      error(e)
    case Done{b}:
      IO.print(B.to_hex(b))

def decoded(r: Result<&2, &1, P.Error, S.PB_kit_fixture_Fixture>, size: U32, depth: Nat) -> IO(Unit):
  match r:
    case Fail{e}:
      error(e)
    case Done{v}:
      encoded(S.encode_PB_kit_fixture_Fixture(v, size, depth))

def input(r: Maybe<&1, B.Bytes>, +size: U32, +depth: Nat) -> IO(Unit):
  match r:
    case None{}:
      IO.die(Unit, 1, "invalid hex")
    case Some{b}:
      decoded(S.decode_PB_kit_fixture_Fixture(b, size, depth), size, depth)

def limits(size: Maybe<&2, U32>, depth: Maybe<&2, U32>, hex: String) -> IO(Unit):
  match size depth:
    case Some{s} Some{d}:
      input(B.from_hex(hex), s, U32.to_nat(d))
    case _ _:
      IO.die(Unit, 1, "invalid limits")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{program, Con{hex, Con{size, Con{depth, Nil{}}}}}:
      limits(U32.read(size), U32.read(depth), hex)
    case _:
      IO.die(Unit, 1, "usage: roundtrip HEX MAX_SIZE DEPTH")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
