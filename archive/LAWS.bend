import Base
import ./archive.bend as Archive
import ../bytes/bytes.bend as Bytes

def octets(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, octets(t)}

def empty_headers(r: Bytes.Bytes & Result<&1, &1, U32 & String, List<&2, Archive.Header>>) -> Bool:
  (b, out) = r
  match out:
    case Fail{e}:
      False{}
    case Done{xs}:
      match xs:
        case Nil{}:
          True{}
        case Con{h, t}:
          False{}

law empty_zip:
  {empty_headers(Archive.headers(Bytes.from_string(octets([80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])))) == True{} : Bool}


law crc32_stored:
  {Archive.crc32(Bytes.from_string("stored")) == 1447295243 : U32}

law crc32_empty:
  {Archive.crc32(Bytes.new(0)) == 0 : U32}

law supports_stored:
  {Archive.supported(0) == True{} : Bool}

law supports_deflate:
  {Archive.supported(8) == True{} : Bool}

law rejects_other_method:
  {Archive.supported(12) == False{} : Bool}
