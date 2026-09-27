import Base
import ./json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def str(t: String) -> Json.Val:
  Json.Str{Json.utf8(t)}

def num(t: String) -> Json.Val:
  Json.Num{Json.utf8(t)}

def obj1(k: String, v: Json.Val) -> Json.Val:
  Json.Obj{Con{(Json.utf8(k), v), Nil{}}}

def obj2(k: String, v: Json.Val, l: String, w: Json.Val) -> Json.Val:
  Json.Obj{Con{(Json.utf8(k), v), Con{(Json.utf8(l), w), Nil{}}}}

# parse.bytes of a byte string, one Char per octet.
def pb(+s: String) -> Maybe<&1, Json.Val>:
  Json.parse.bytes(Bytes.from_string(s))

def got(m: Maybe<&1, Json.Val>, k: String) -> Maybe<&1, Json.Val>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      Json.get(v, k)

# encode.bytes as a byte string.
def eb(v: Json.Val) -> String:
  Bytes.to_string(Json.encode.bytes(v))

# RFC 8259 §3: literal names.
law parse_null:
  {pb("null") == Some{Json.Null{}} : Maybe<&1, Json.Val>}

law parse_true:
  {pb("true") == Some{Json.Flag{True{}}} : Maybe<&1, Json.Val>}

law parse_false:
  {pb("false") == Some{Json.Flag{False{}}} : Maybe<&1, Json.Val>}

law parse_empty_arr:
  {pb("[]") == Some{Json.Arr{Nil{}}} : Maybe<&1, Json.Val>}

law parse_empty_obj:
  {pb("{}") == Some{Json.Obj{Nil{}}} : Maybe<&1, Json.Val>}

law at_index:
  {Json.at(Json.Arr{Con{str("a"), Con{str("b"), Nil{}}}}, 1n) == Some{str("b")} : Maybe<&1, Json.Val>}

law at_object_none:
  {Json.at(Json.Null{}, 0n) == None{} : Maybe<&1, Json.Val>}

law get_key:
  {got(pb("{\"a\":1,\"b\":[true]}"), "b") == Some{Json.Arr{Con{Json.Flag{True{}}, Nil{}}}} : Maybe<&1, Json.Val>}

law get_missing_none:
  {got(pb("{\"a\":1}"), "b") == None{} : Maybe<&1, Json.Val>}

law get_utf8_key:
  {got(pb("{\"\u{c3}\u{a9}\":1}"), "é") == Some{num("1")} : Maybe<&1, Json.Val>}

law get_array_none:
  {got(pb("[1]"), "a") == None{} : Maybe<&1, Json.Val>}

law u32_twelve:
  {Json.u32(num("12")) == Some{12} : Maybe<&2, U32>}

law u32_fraction_none:
  {Json.u32(num("1.5")) == None{} : Maybe<&2, U32>}

law u32_overflow_none:
  {Json.u32(num("4294967296")) == None{} : Maybe<&2, U32>}

# §2: one value per text.
law trailing_junk:
  {pb("null x") == None{} : Maybe<&1, Json.Val>}

# Fields keep document order.
law parse_nested:
  {pb("{\"c\":[1,{\"b\":null}],\"a\":\"x\"}") == Some{obj2("c", Json.Arr{Con{num("1"), Con{obj1("b", Json.Null{}), Nil{}}}}, "a", str("x"))} : Maybe<&1, Json.Val>}

# §2: insignificant whitespace around structural characters.
law parse_ws:
  {pb(" \t{ \"a\" :\n[ 1 , 2 ]\r\n} ") == Some{obj1("a", Json.Arr{Con{num("1"), Con{num("2"), Nil{}}}})} : Maybe<&1, Json.Val>}

law parse_deep:
  {pb("[[[[[]]]]]") == Some{Json.Arr{Con{Json.Arr{Con{Json.Arr{Con{Json.Arr{Con{Json.Arr{Nil{}}, Nil{}}}, Nil{}}}, Nil{}}}, Nil{}}}} : Maybe<&1, Json.Val>}

law empty_containers:
  {pb("[{},[ ],{ }]") == Some{Json.Arr{Con{Json.Obj{Nil{}}, Con{Json.Arr{Nil{}}, Con{Json.Obj{Nil{}}, Nil{}}}}}} : Maybe<&1, Json.Val>}

law literals:
  {pb("[true,false,null]") == Some{Json.Arr{Con{Json.Flag{True{}}, Con{Json.Flag{False{}}, Con{Json.Null{}, Nil{}}}}}} : Maybe<&1, Json.Val>}

# §4: names SHOULD be unique. Obj keeps both fields; get, like most parsers, takes the last.
law dup_key_kept:
  {pb("{\"a\":1,\"a\":2}") == Some{obj2("a", num("1"), "a", num("2"))} : Maybe<&1, Json.Val>}

law dup_key_last:
  {got(pb("{\"a\":1,\"a\":2}"), "a") == Some{num("2")} : Maybe<&1, Json.Val>}

# §6: number grammar; the text is kept exactly.
law num_neg_frac_exp:
  {pb("-12.5e+3") == Some{num("-12.5e+3")} : Maybe<&1, Json.Val>}

law num_neg_zero:
  {pb("-0") == Some{num("-0")} : Maybe<&1, Json.Val>}

law num_big_exp:
  {pb("1E400") == Some{num("1E400")} : Maybe<&1, Json.Val>}

law num_in_arr:
  {pb("[0,-0.5,1E400]") == Some{Json.Arr{Con{num("0"), Con{num("-0.5"), Con{num("1E400"), Nil{}}}}}} : Maybe<&1, Json.Val>}

law num_leading_zero_rejects:
  {pb("01") == None{} : Maybe<&1, Json.Val>}

law num_bare_minus_rejects:
  {pb("-") == None{} : Maybe<&1, Json.Val>}

law num_dot_end_rejects:
  {pb("1.") == None{} : Maybe<&1, Json.Val>}

law num_dot_start_rejects:
  {pb(".5") == None{} : Maybe<&1, Json.Val>}

law num_exp_end_rejects:
  {pb("1e") == None{} : Maybe<&1, Json.Val>}

law num_plus_rejects:
  {pb("+1") == None{} : Maybe<&1, Json.Val>}

# §7: escapes decode to UTF-8.
law str_escapes:
  {pb("\"a\\\"b\\\\c\\/d\\n\\t\"") == Some{str("a\"b\\c/d\n\t")} : Maybe<&1, Json.Val>}

law str_escape_after_word:
  {pb("\"abcd\\nh\u{c3}\u{a9}\\t\"") == Some{str("abcd\nhé\t")} : Maybe<&1, Json.Val>}

law str_unicode_pair:
  {pb("\"\\u00e9\\ud83d\\ude00\"") == Some{str("é😀")} : Maybe<&1, Json.Val>}

# §8.2: an unpaired surrogate becomes U+FFFD.
law str_lone_surrogate:
  {pb("\"\\ud83dx\"") == Some{str("\u{FFFD}x")} : Maybe<&1, Json.Val>}

law str_lone_surrogates:
  {pb("\"\\ud83dx\\udc00\"") == Some{str("\u{FFFD}x\u{FFFD}")} : Maybe<&1, Json.Val>}

law str_bad_hex_rejects:
  {pb("\"\\ud83d\\uzzzz\"") == None{} : Maybe<&1, Json.Val>}

law str_raw_control_rejects:
  {pb("\"a\nb\"") == None{} : Maybe<&1, Json.Val>}

law str_bad_escape_rejects:
  {pb("\"\\x\"") == None{} : Maybe<&1, Json.Val>}

law str_unterminated_rejects:
  {pb("\"abc") == None{} : Maybe<&1, Json.Val>}

law short_literal_rejects:
  {pb("tru") == None{} : Maybe<&1, Json.Val>}

# The end of input is not a NUL byte.
law nul_rejects:
  {pb("1\u{0}") == None{} : Maybe<&1, Json.Val>}

# §5, §4: structure.
law arr_trailing_comma_rejects:
  {pb("[1,]") == None{} : Maybe<&1, Json.Val>}

law arr_missing_comma_rejects:
  {pb("[1 2]") == None{} : Maybe<&1, Json.Val>}

law wrong_close_rejects:
  {pb("[1}") == None{} : Maybe<&1, Json.Val>}

law empty_wrong_close_rejects:
  {pb("{]") == None{} : Maybe<&1, Json.Val>}

law obj_missing_colon_rejects:
  {pb("{\"a\" 1}") == None{} : Maybe<&1, Json.Val>}

law obj_trailing_comma_rejects:
  {pb("{\"a\":1,}") == None{} : Maybe<&1, Json.Val>}

law obj_number_key_rejects:
  {pb("{1:2}") == None{} : Maybe<&1, Json.Val>}

law unclosed_rejects:
  {pb("[{\"a\":[1]") == None{} : Maybe<&1, Json.Val>}

law empty_rejects:
  {pb("  ") == None{} : Maybe<&1, Json.Val>}

# UTF-8 in strings and keys is kept.
law utf8_two:
  {pb("\"h\u{c3}\u{a9}\"") == Some{str("hé")} : Maybe<&1, Json.Val>}

law utf8_three_four_key:
  {pb("{\"\u{f0}\u{9f}\u{98}\u{80}\":\"\u{e2}\u{82}\u{ac}\"}") == Some{obj1("😀", str("€"))} : Maybe<&1, Json.Val>}

# §8.1: JSON text is UTF-8, so bad UTF-8 rejects.
law utf8_lone_continuation_rejects:
  {pb("\"\u{80}\"") == None{} : Maybe<&1, Json.Val>}

law utf8_overlong_rejects:
  {pb("\"\u{c0}\u{af}\"") == None{} : Maybe<&1, Json.Val>}

law utf8_surrogate_rejects:
  {pb("\"\u{ed}\u{a0}\u{80}\"") == None{} : Maybe<&1, Json.Val>}

law utf8_past_max_rejects:
  {pb("\"\u{f4}\u{90}\u{80}\u{80}\"") == None{} : Maybe<&1, Json.Val>}

law utf8_truncated_rejects:
  {pb("\"\u{c3}\"") == None{} : Maybe<&1, Json.Val>}

law utf8_truncated_at_end_rejects:
  {pb("\"\u{e2}\u{82}") == None{} : Maybe<&1, Json.Val>}

law non_ascii_outside_string_rejects:
  {pb("\u{c3}\u{a9}") == None{} : Maybe<&1, Json.Val>}

# Encoding is compact, with fields in their order.
law encode_compact:
  {eb(obj2("b", Json.Arr{Con{num("1"), Con{num("-2.5e3"), Con{Json.Flag{True{}}, Con{Json.Null{}, Nil{}}}}}}, "a", Json.Obj{Nil{}})) == "{\"b\":[1,-2.5e3,true,null],\"a\":{}}" : String}

# §7: quote, backslash and control chars are escaped; other UTF-8 is kept.
law encode_escapes:
  {eb(obj1("k\u{e9}", str("a\"\\\n\r\t\u{1}\u{1f}\u{20ac}\u{1F600}"))) == "{\"k\u{c3}\u{a9}\":\"a\\\"\\\\\\n\\r\\t\\u0001\\u001f\u{e2}\u{82}\u{ac}\u{f0}\u{9f}\u{98}\u{80}\"}" : String}

# The buffer holds the fewest words, as Bytes requires, below and past its first size.
law encode_small_buffer:
  {Json.encode.bytes(Json.Null{}) == Bytes.from_string("null") : Bytes.Bytes}

law encode_grown_buffer:
  {Json.encode.bytes(str("0123456789012345678901234567890123456789012345678901234567890123456789")) == Bytes.from_string("\"0123456789012345678901234567890123456789012345678901234567890123456789\"") : Bytes.Bytes}

law roundtrip:
  {Json.parse.bytes(Json.encode.bytes(obj1("k\"ey", Json.Arr{Con{str("é\n😀"), Con{Json.Null{}, Con{num("-0.5"), Nil{}}}}}))) == Some{obj1("k\"ey", Json.Arr{Con{str("é\n😀"), Con{Json.Null{}, Con{num("-0.5"), Nil{}}}}})} : Maybe<&1, Json.Val>}
