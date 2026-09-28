import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./multipart.bend as Mp

def txt(s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def octets(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, octets(t)}

def opt(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "-"
    case Some{s}:
      s

# A part as name|filename|ctype|body; "-" for none.
def part.show(p: Mp.Part) -> String:
  Mp.Part{n, f, c, b} = p
  n ++ "|" ++ opt(f) ++ "|" ++ opt(c) ++ "|" ++ Bytes.to_string(b) ++ ";"

def parts.show(ps: List<&1, Mp.Part>) -> String:
  match ps:
    case Nil{}:
      SNil{}
    case Con{p, t}:
      part.show(p) ++ parts.show(t)

def decoded(r: Result<&1, &1, String, List<&1, Mp.Part>>) -> String:
  match r:
    case Fail{e}:
      "!" ++ e
    case Done{ps}:
      parts.show(ps)

def encoded(r: Result<&1, &1, String, Bytes.Bytes>) -> String:
  match r:
    case Fail{e}:
      "!" ++ e
    case Done{b}:
      Bytes.to_string(b)

def roundtrip(+b: String, r: Result<&1, &1, String, Bytes.Bytes>) -> String:
  match r:
    case Fail{e}:
      "!" ++ e
    case Done{body}:
      decoded(Mp.decode(b, body))

def two() -> List<&1, Mp.Part>:
  [Mp.Part{"a", None{}, None{}, txt("1")}, Mp.Part{"f", Some{"x.txt"}, Some{"text/plain"}, txt("hi")}]

# RFC 7578 §4.1: dash-boundary CRLF, headers, CRLF, body; CRLF before each next delimiter; close with "--".
law encode_two:
  {encoded(Mp.encode("B", two())) == "--B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\n1\r\n--B\r\nContent-Disposition: form-data; name=\"f\"; filename=\"x.txt\"\r\nContent-Type: text/plain\r\n\r\nhi\r\n--B--\r\n" : String}

law encode_empty:
  {encoded(Mp.encode("B", Nil{})) == "--B--\r\n" : String}

# WHATWG: '"', CR, and LF in a name are percent-escaped, and decoding undoes it.
law encode_escapes_name:
  {encoded(Mp.encode("B", [Mp.Part{"a\"b\r\n", None{}, None{}, txt("")}])) == "--B\r\nContent-Disposition: form-data; name=\"a%22b%0D%0A\"\r\n\r\n\r\n--B--\r\n" : String}

law roundtrip_two:
  {roundtrip("B", Mp.encode("B", two())) == "a|-|-|1;f|x.txt|text/plain|hi;" : String}

law roundtrip_escaped_name:
  {roundtrip("B", Mp.encode("B", [Mp.Part{"q\"n", Some{"a\"b"}, None{}, txt("v")}])) == "q\"n|a\"b|-|v;" : String}

# Binary octets, CR, LF, and dashes in a body are data.
law roundtrip_binary:
  {roundtrip("B", Mp.encode("B", [Mp.Part{"z", None{}, None{}, txt(octets([0, 13, 10, 45, 45, 67, 255]))}])) == "z|-|-|" ++ octets([0, 13, 10, 45, 45, 67, 255]) ++ ";" : String}

# RFC 2046 §5.1.1: the boundary is 1 to 70 bchars and must not occur in a body.
law encode_rejects_boundary_in_body:
  {encoded(Mp.encode("B", [Mp.Part{"a", None{}, None{}, txt("x\r\n--B")}])) == "!multipart: boundary occurs in a part body" : String}

law encode_rejects_bad_boundary:
  {encoded(Mp.encode("a b ", Nil{})) == "!multipart: boundary must be 1 to 70 RFC 2046 bchars, not ending in a space" : String}

law encode_rejects_empty_boundary:
  {encoded(Mp.encode("", Nil{})) == "!multipart: boundary must be 1 to 70 RFC 2046 bchars, not ending in a space" : String}

law encode_rejects_header_injection:
  {encoded(Mp.encode("B", [Mp.Part{"a", None{}, Some{"text/plain\r\nX: y"}, txt("")}])) == "!multipart: Content-Type has CR or LF" : String}

# Delimiters and header blocks split across chunks are still found.
law chunks_split_delimiter:
  {decoded(Mp.decode.chunks("B", [txt("--B\r\nContent-Disposition: form-data; name=a\r\n\r\nxy\r\n-"), txt("-"), txt("B--\r\n")])) == "a|-|-|xy;" : String}

law chunks_split_headers:
  {decoded(Mp.decode.chunks("B", [txt("--B\r\nContent-Dispo"), txt("sition: form-data; name=\"a\"\r"), txt("\n\r\nv\r\n--B--")])) == "a|-|-|v;" : String}

# A near-delimiter held back at a chunk end is released as body when it does not complete.
law chunks_false_delimiter:
  {decoded(Mp.decode.chunks("B", [txt("--B\r\nContent-Disposition: form-data; name=a\r\n\r\nx\r\n-"), txt("-C\r\n--B--")])) == "a|-|-|x\r\n--C;" : String}

# RFC 2046 §5.1.1: preamble and epilogue are ignored; transport padding may follow a boundary.
law preamble_epilogue:
  {decoded(Mp.decode("B", txt("junk\r\n--B \t\r\ncontent-disposition: FORM-DATA; filename=\"f\"; name=\"a;b\"\r\nX-Other: 1\r\n\r\nv\r\n--B--\r\nafter"))) == "a;b|f|-|v;" : String}

# RFC 2046 §5.1.1: a delimiter is CRLF "--" boundary then "--" or padding and CRLF. With boundary B,
# "\r\n--Bextra" is data, in the preamble and in a body, whole or split just after the prefix.
law decode_boundary_prefix_is_data:
  {decoded(Mp.decode("B", txt("--Bx\r\n--B\r\nContent-Disposition: form-data; name=a\r\n\r\nx\r\n--Bextra\r\ny\r\n--B--"))) == "a|-|-|x\r\n--Bextra\r\ny;" : String}

law chunks_boundary_prefix_is_data:
  {decoded(Mp.decode.chunks("B", [txt("--B\r\nContent-Disposition: form-data; name=a\r\n\r\nx\r\n--B"), txt("extra\r\ny\r\n--B"), txt("--")])) == "a|-|-|x\r\n--Bextra\r\ny;" : String}

law decode_missing_name:
  {decoded(Mp.decode("B", txt("--B\r\nContent-Disposition: form-data\r\n\r\nv\r\n--B--"))) == "!multipart: part has no name" : String}

law decode_no_headers:
  {decoded(Mp.decode("B", txt("--B\r\n\r\nv\r\n--B--"))) == "!multipart: part has no Content-Disposition" : String}

law decode_not_form_data:
  {decoded(Mp.decode("B", txt("--B\r\nContent-Disposition: attachment; name=a\r\n\r\nv\r\n--B--"))) == "!multipart: Content-Disposition is not form-data" : String}

law decode_truncated:
  {decoded(Mp.decode("B", txt("--B\r\nContent-Disposition: form-data; name=a\r\n\r\nv"))) == "!multipart: body ends before the close delimiter" : String}

law boundary_get_quoted:
  {Mp.boundary.get("multipart/form-data; boundary=\"a b\"") == Some{"a b"} : Maybe<&2, String>}

law boundary_get_token:
  {Mp.boundary.get("Multipart/Form-Data;charset=utf-8; BOUNDARY=xyz ") == Some{"xyz"} : Maybe<&2, String>}

law boundary_get_missing:
  {Mp.boundary.get("text/plain") == None{} : Maybe<&2, String>}
