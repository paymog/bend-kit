import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import ../protobuf.bend as P
import ./schema.bend as S

def encoded(r: Result<&2, &1, P.Error, B.Bytes>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "typed child encoding failed")
    case Done{bytes}:
      IO.print(B.to_hex(bytes))

def main() -> IO(Unit):
  encoded(S.encode_PB_kit_common_Child(S.PB_kit_common_Child{150, "from Bend", None{}, Nil{}}, 1024, 8n))
