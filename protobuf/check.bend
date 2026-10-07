import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import ./protobuf.bend as P
import ./examples/schema.bend as S

def error(e: P.Error) -> String:
  match e:
    case P.Incomplete{}:
      "incomplete"
    case P.Malformed{}:
      "malformed"
    case P.Limit{}:
      "limit"
    case P.InvalidUtf8{}:
      "utf8"

def encoded(r: Result<&2, &1, P.Error, B.Bytes>) -> String:
  match r:
    case Fail{e}:
      error(e)
    case Done{b}:
      B.to_hex(b)

def decoded(r: Result<&2, &1, P.Error, List<&1, P.Field>>, size: U32, depth: Nat) -> String:
  match r:
    case Fail{e}:
      error(e)
    case Done{fields}:
      encoded(P.encode(fields, size, depth))

def input(r: Maybe<&1, B.Bytes>, +size: U32, +depth: Nat) -> String:
  match r:
    case None{}:
      "invalid hex"
    case Some{b}:
      decoded(P.decode(b, size, depth), size, depth)

def roundtrip(hex: String) -> String:
  input(B.from_hex(hex), 1024, 16n)

def assert.equal(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "protobuf check failed: " ++ label)

def check(+hex: String, expected: String) -> IO(Unit):
  assert.equal(String.eq(roundtrip(hex), expected), hex)

def main() -> IO(Unit):
  do IO<Unit>:
    check("", "")
    check("089601", "089601")
    check("08ffffffffffffffffff01", "08ffffffffffffffffff01")
    check("f8ffffff0f01", "f8ffffff0f01")
    check("0d78563412", "0d78563412")
    check("091032547698badcfe", "091032547698badcfe")
    check("0a030080ff", "0a030080ff")
    check("0b1096010c", "0b1096010c")
    check("00", "malformed")
    check("0e", "malformed")
    check("80", "incomplete")
    check("0880", "incomplete")
    check("08ffffffffffffffffff02", "malformed")
    check("0b14", "malformed")
    check("0a8080808008", "malformed")
    check("88808080800001", "malformed")
    check("0a81808080800078", "malformed")
    assert.equal(String.eq(encoded(P.encode([P.Field{0, P.Varint{P.Word64{0, 1}}}], 1024, 16n)), "malformed"), "encode field zero")
    assert.equal(String.eq(encoded(P.encode([P.Field{536870912, P.Varint{P.Word64{0, 1}}}], 1024, 16n)), "malformed"), "encode field overflow")
    assert.equal(String.eq(encoded(P.encode([P.Field{1, P.Varint{P.Word64{0, 150}}}], 2, 16n)), "limit"), "encode size limit")
    assert.equal(String.eq(input(B.from_hex("0b1300140c"), 1024, 1n), "limit"), "group depth limit")
    assert.equal(String.eq(encoded(S.encode_PB_kit_fixture_Fixture(S.PB_kit_fixture_Fixture.empty(), 1024, 8n)), ""), "typed empty defaults")
    assert.equal(String.eq(encoded(S.encode_PB_kit_common_Child(S.PB_kit_common_Child{150, "", None{}, Nil{}}, 2, 8n)), "limit"), "typed encode size limit")
    assert.equal(String.eq(encoded(P.encode([P.Field{1, P.Group{[P.Field{2, P.Group{[P.Field{3, P.Varint{P.Word64{0, 7}}}]} }]} }], 1024, 1n)), "limit"), "encode nested group lower depth")
    assert.equal(String.eq(encoded(P.encode([P.Field{1, P.Group{[P.Field{2, P.Group{[P.Field{3, P.Varint{P.Word64{0, 7}}}]} }]} }], 1024, 2n)), "0b131807140c"), "encode nested group exact depth")
    assert.equal(String.eq(encoded(S.encode_PB_kit_common_Child(S.PB_kit_common_Child{1, "", Some{S.PB_kit_common_Child{2, "", None{}, Nil{}}}, Nil{}}, 1024, 0n)), "limit"), "typed recursive encode lower depth")
    assert.equal(String.eq(encoded(S.encode_PB_kit_common_Child(S.PB_kit_common_Child{1, "", Some{S.PB_kit_common_Child{2, "", None{}, Nil{}}}, Nil{}}, 1024, 1n)), "08011a020802"), "typed recursive encode exact depth")
    assert.equal(String.eq(encoded(S.encode_PB_kit_common_Child(S.PB_kit_common_Child{1, "", None{}, Nil{}}, 1024, 0n)), "0801"), "typed flat encode zero depth")
    IO.print("protobuf wire checks passed")
