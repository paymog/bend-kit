import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import bend-kit-f64@0.1.0.0/f64.bend as F
import ../protobuf.bend as P
import ./schema.bend as S

def encoded(r: Result<&2, &1, P.Error, B.Bytes>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "typed oracle encoding failed")
    case Done{bytes}:
      IO.print(B.to_hex(bytes))

# Report typed limbs and IEEE payloads independently of the encoder.
def decoded(r: Result<&2, &1, P.Error, S.PB_kit_fixture_Scalars>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "typed oracle decoding failed")
    case Done{S.PB_kit_fixture_Scalars{i32, z32, P.Word64{ih, il}, P.Word64{zh, zl}, P.Word64{uh, ul}, single, F.F64{dh, dl}, unknown}}:
      do IO<Unit>:
        IO.print(U32.show(i32))
        IO.print(U32.show(z32))
        IO.print(U32.show(ih))
        IO.print(U32.show(il))
        IO.print(U32.show(zh))
        IO.print(U32.show(zl))
        IO.print(U32.show(uh))
        IO.print(U32.show(ul))
        IO.print(U32.show(F32.bits(single)))
        IO.print(U32.show(dh))
        IO.print(U32.show(dl))

def input(r: Maybe<&1, B.Bytes>) -> IO(Unit):
  match r:
    case None{}:
      IO.die(Unit, 1, "invalid hex")
    case Some{bytes}:
      decoded(S.decode_PB_kit_fixture_Scalars(bytes, 1024, 0n))

def construct() -> IO(Unit):
  encoded(S.encode_PB_kit_fixture_Scalars(S.PB_kit_fixture_Scalars{2147483648, 4171510507, P.Word64{2147483648, 0}, P.Word64{4275878552, 1985229329}, P.Word64{4294967295, 4294967295}, P.float_of_bits(3240314215), F.F64{3222418518, 2023406814}, Nil{}}, 1024, 0n))

def collision() -> IO(Unit):
  do IO<Unit>:
    encoded(S.encode_PB_kit_fixture_A_0(S.PB_kit_fixture_A_0{Some{S.PB_kit_fixture_A_0_B{150, Nil{}}}, Nil{}}, 1024, 1n))
    encoded(S.encode_PB_kit_fixture_A(S.PB_kit_fixture_A{Some{S.PB_kit_fixture_A__0B{"distinct string child", Nil{}}}, Nil{}}, 1024, 1n))

def short_mode(mode: String) -> IO(Unit):
  match mode:
    case "construct": construct()
    case "collision": collision()
    case _: IO.die(Unit, 1, "usage: scalars construct | collision | decode HEX")

def decode_mode(mode: String, hex: String) -> IO(Unit):
  match mode:
    case "decode": input(B.from_hex(hex))
    case _: IO.die(Unit, 1, "usage: scalars construct | collision | decode HEX")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{program, Con{mode, Nil{}}}:
      short_mode(mode)
    case Con{program, Con{mode, Con{hex, Nil{}}}}:
      decode_mode(mode, hex)
    case _:
      IO.die(Unit, 1, "usage: scalars construct | collision | decode HEX")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
