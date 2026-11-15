import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import ./encoding.bend as Enc

def octets(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, octets(t)}

law utf8_empty:
  {Bytes.to_string(Enc.utf8.encode("")) == "" : String}

law utf8_decode_empty:
  {Enc.utf8.decode(Bytes.new(0)) == "" : String}

# RFC 3629 §3: ASCII is one octet, unchanged.
law utf8_ascii:
  {Bytes.to_string(Enc.utf8.encode("GET /")) == "GET /" : String}

# RFC 3629 §3: one example per sequence length.
law utf8_two:
  {Bytes.to_string(Enc.utf8.encode("é")) == octets([195, 169]) : String}

law utf8_three:
  {Bytes.to_string(Enc.utf8.encode("€")) == octets([226, 130, 172]) : String}

law utf8_four:
  {Bytes.to_string(Enc.utf8.encode("😀")) == octets([240, 159, 152, 128]) : String}

law utf8_roundtrip:
  {Enc.utf8.decode(Enc.utf8.encode("aé€😀z")) == "aé€😀z" : String}

# WHATWG: bytes that cannot start a sequence decode to U+FFFD.
law utf8_bad_lead:
  {Enc.utf8.decode(Bytes.from_string(octets([255, 65]))) == "\u{FFFD}A" : String}

# WHATWG: a broken sequence yields one U+FFFD and the breaking byte is read again.
law utf8_reprocess:
  {Enc.utf8.decode(Bytes.from_string(octets([195, 65]))) == "\u{FFFD}A" : String}

law utf8_truncated:
  {Enc.utf8.decode(Bytes.from_string(octets([226, 130]))) == "\u{FFFD}" : String}

# RFC 3629 §3: overlong forms and surrogates are not UTF-8.
law utf8_overlong:
  {Enc.utf8.decode(Bytes.from_string(octets([192, 128]))) == "\u{FFFD}\u{FFFD}" : String}

law utf8_surrogate:
  {Enc.utf8.decode(Bytes.from_string(octets([237, 160, 128]))) == "\u{FFFD}\u{FFFD}\u{FFFD}" : String}
