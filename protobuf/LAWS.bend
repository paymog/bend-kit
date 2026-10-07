import Base
import ./check.bend as Check

law empty_roundtrip:
  {Check.roundtrip("") == "" : String}

law varint_roundtrip:
  {Check.roundtrip("089601") == "089601" : String}

law uint64_boundary_roundtrip:
  {Check.roundtrip("08ffffffffffffffffff01") == "08ffffffffffffffffff01" : String}

law field_number_boundary_roundtrip:
  {Check.roundtrip("f8ffffff0f01") == "f8ffffff0f01" : String}

law fixed32_roundtrip:
  {Check.roundtrip("0d78563412") == "0d78563412" : String}

law fixed64_roundtrip:
  {Check.roundtrip("091032547698badcfe") == "091032547698badcfe" : String}

law packed_bytes_roundtrip:
  {Check.roundtrip("0a030080ff") == "0a030080ff" : String}

law group_roundtrip:
  {Check.roundtrip("0b1096010c") == "0b1096010c" : String}

law incomplete_varint:
  {Check.roundtrip("0880") == "incomplete" : String}

law overflowing_varint:
  {Check.roundtrip("08ffffffffffffffffff02") == "malformed" : String}

law invalid_tag:
  {Check.roundtrip("00") == "malformed" : String}

law mismatched_group:
  {Check.roundtrip("0b14") == "malformed" : String}
