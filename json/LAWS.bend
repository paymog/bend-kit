import Base
import ./json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def obj1(k: String, v: Json.Val) -> Json.Val:
  Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), k, v)}

# parse.bytes of a byte string, one Char per octet.
def pb(+s: String) -> Maybe<&2, Json.Val>:
  Json.parse.bytes(Bytes.from_string(s))

# encode.bytes as a byte string.
def eb(v: Json.Val) -> String:
  Bytes.to_string(Json.encode.bytes(v))

# RFC 8259 §3: literal names.
law parse_null:
  {Json.parse("null") == Some{Json.Null{}} : Maybe<&2, Json.Val>}

law parse_true:
  {Json.parse("true") == Some{Json.Flag{True{}}} : Maybe<&2, Json.Val>}

law parse_false:
  {Json.parse("false") == Some{Json.Flag{False{}}} : Maybe<&2, Json.Val>}

law parse_empty_arr:
  {Json.parse("[]") == Some{Json.Arr{Nil{}}} : Maybe<&2, Json.Val>}

law parse_empty_obj:
  {Json.parse("{}") == Some{Json.Obj{Map.new(&2, Json.Val)}} : Maybe<&2, Json.Val>}

law at_index:
  {Json.at(Json.Arr{[Json.Str{"a"}, Json.Str{"b"}]}, 1n) == Some{Json.Str{"b"}} : Maybe<&2, Json.Val>}

law at_object_none:
  {Json.at(Json.Null{}, 0n) == None{} : Maybe<&2, Json.Val>}

law u32_twelve:
  {Json.u32(Json.Num{"12"}) == Some{12} : Maybe<&2, U32>}

law u32_fraction_none:
  {Json.u32(Json.Num{"1.5"}) == None{} : Maybe<&2, U32>}

law u32_overflow_none:
  {Json.u32(Json.Num{"4294967296"}) == None{} : Maybe<&2, U32>}

# §2: one value per text.
law trailing_junk:
  {Json.parse("null x") == None{} : Maybe<&2, Json.Val>}

law parse_nested:
  {Json.parse("{\"a\":[1,{\"b\":null}],\"c\":\"x\"}") == Some{Json.Obj{Map.set(&2, Json.Val, Map.set(&2, Json.Val, Map.new(&2, Json.Val), "a", Json.Arr{[Json.Num{"1"}, obj1("b", Json.Null{})]}), "c", Json.Str{"x"})}} : Maybe<&2, Json.Val>}

# §2: insignificant whitespace around structural characters.
law parse_ws:
  {Json.parse(" \t{ \"a\" :\n[ 1 , 2 ]\r\n} ") == Some{obj1("a", Json.Arr{[Json.Num{"1"}, Json.Num{"2"}]})} : Maybe<&2, Json.Val>}

law parse_deep:
  {Json.parse("[[[[[]]]]]") == Some{Json.Arr{[Json.Arr{[Json.Arr{[Json.Arr{[Json.Arr{Nil{}}]}]}]}]}} : Maybe<&2, Json.Val>}

# §4: names SHOULD be unique; like most parsers, the last one wins.
law dup_key_last:
  {Json.parse("{\"a\":1,\"a\":2}") == Some{obj1("a", Json.Num{"2"})} : Maybe<&2, Json.Val>}

# §6: number grammar; the text is kept exactly.
law num_neg_frac_exp:
  {Json.parse("-12.5e+3") == Some{Json.Num{"-12.5e+3"}} : Maybe<&2, Json.Val>}

law num_neg_zero:
  {Json.parse("-0") == Some{Json.Num{"-0"}} : Maybe<&2, Json.Val>}

law num_big_exp:
  {Json.parse("1E400") == Some{Json.Num{"1E400"}} : Maybe<&2, Json.Val>}

law num_leading_zero_rejects:
  {Json.parse("01") == None{} : Maybe<&2, Json.Val>}

law num_bare_minus_rejects:
  {Json.parse("-") == None{} : Maybe<&2, Json.Val>}

law num_dot_end_rejects:
  {Json.parse("1.") == None{} : Maybe<&2, Json.Val>}

law num_dot_start_rejects:
  {Json.parse(".5") == None{} : Maybe<&2, Json.Val>}

law num_exp_end_rejects:
  {Json.parse("1e") == None{} : Maybe<&2, Json.Val>}

law num_plus_rejects:
  {Json.parse("+1") == None{} : Maybe<&2, Json.Val>}

# §7: escapes.
law str_escapes:
  {Json.parse("\"a\\\"b\\\\c\\/d\\n\\t\"") == Some{Json.Str{"a\"b\\c/d\n\t"}} : Maybe<&2, Json.Val>}

law str_unicode_pair:
  {Json.parse("\"\\u00e9\\ud83d\\ude00\"") == Some{Json.Str{"é😀"}} : Maybe<&2, Json.Val>}

# §8.2: an unpaired surrogate becomes U+FFFD.
law str_lone_surrogate:
  {Json.parse("\"\\ud83dx\"") == Some{Json.Str{"\u{FFFD}x"}} : Maybe<&2, Json.Val>}

law str_raw_control_rejects:
  {Json.parse("\"a\nb\"") == None{} : Maybe<&2, Json.Val>}

law str_bad_escape_rejects:
  {Json.parse("\"\\x\"") == None{} : Maybe<&2, Json.Val>}

law str_unterminated_rejects:
  {Json.parse("\"abc") == None{} : Maybe<&2, Json.Val>}

# §5, §4: structure.
law arr_trailing_comma_rejects:
  {Json.parse("[1,]") == None{} : Maybe<&2, Json.Val>}

law arr_missing_comma_rejects:
  {Json.parse("[1 2]") == None{} : Maybe<&2, Json.Val>}

law obj_missing_colon_rejects:
  {Json.parse("{\"a\" 1}") == None{} : Maybe<&2, Json.Val>}

law obj_trailing_comma_rejects:
  {Json.parse("{\"a\":1,}") == None{} : Maybe<&2, Json.Val>}

law obj_number_key_rejects:
  {Json.parse("{1:2}") == None{} : Maybe<&2, Json.Val>}

law unclosed_rejects:
  {Json.parse("[{\"a\":[1]") == None{} : Maybe<&2, Json.Val>}

law empty_rejects:
  {Json.parse("  ") == None{} : Maybe<&2, Json.Val>}

# Encoding is compact with sorted keys.
law encode_canonical:
  {Json.encode(Json.Obj{Map.set(&2, Json.Val, Map.set(&2, Json.Val, Map.new(&2, Json.Val), "b", Json.Arr{[Json.Num{"1"}, Json.Num{"-2.5e3"}, Json.Flag{True{}}]}), "a", Json.Obj{Map.new(&2, Json.Val)})}) == "{\"a\":{},\"b\":[1,-2.5e3,true]}" : String}

# §7: quote, backslash and control chars are escaped.
law encode_escapes:
  {Json.encode(Json.Str{"a\"\\\n\u{1}"}) == "\"a\\\"\\\\\\n\\u0001\"" : String}

law roundtrip:
  {Json.parse(Json.encode(Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})})) == Some{Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})}} : Maybe<&2, Json.Val>}

# Bytes: the text path's fixtures give the same answers.
law bytes_nested:
  {pb("{\"a\":[1,{\"b\":null}],\"c\":\"x\"}") == Json.parse("{\"a\":[1,{\"b\":null}],\"c\":\"x\"}") : Maybe<&2, Json.Val>}

law bytes_ws:
  {pb(" \t{ \"a\" :\n[ 1 , 2 ]\r\n} ") == Some{obj1("a", Json.Arr{[Json.Num{"1"}, Json.Num{"2"}]})} : Maybe<&2, Json.Val>}

law bytes_deep:
  {pb("[[[[[]]]]]") == Json.parse("[[[[[]]]]]") : Maybe<&2, Json.Val>}

law bytes_empty_containers:
  {pb("[{},[ ],{ }]") == Some{Json.Arr{[Json.Obj{Map.new(&2, Json.Val)}, Json.Arr{Nil{}}, Json.Obj{Map.new(&2, Json.Val)}]}} : Maybe<&2, Json.Val>}

law bytes_literals:
  {pb("[true,false,null]") == Some{Json.Arr{[Json.Flag{True{}}, Json.Flag{False{}}, Json.Null{}]}} : Maybe<&2, Json.Val>}

law bytes_dup_key_last:
  {pb("{\"a\":1,\"a\":2}") == Some{obj1("a", Json.Num{"2"})} : Maybe<&2, Json.Val>}

law bytes_num_at_end:
  {pb("-12.5e+3") == Some{Json.Num{"-12.5e+3"}} : Maybe<&2, Json.Val>}

law bytes_num_in_arr:
  {pb("[0,-0.5,1E400]") == Some{Json.Arr{[Json.Num{"0"}, Json.Num{"-0.5"}, Json.Num{"1E400"}]}} : Maybe<&2, Json.Val>}

law bytes_num_leading_zero_rejects:
  {pb("01") == None{} : Maybe<&2, Json.Val>}

law bytes_num_dot_end_rejects:
  {pb("1.") == None{} : Maybe<&2, Json.Val>}

law bytes_escapes:
  {pb("\"a\\\"b\\\\c\\/d\\n\\t\"") == Some{Json.Str{"a\"b\\c/d\n\t"}} : Maybe<&2, Json.Val>}

law bytes_unicode_pair:
  {pb("\"\\u00e9\\ud83d\\ude00\"") == Some{Json.Str{"é😀"}} : Maybe<&2, Json.Val>}

law bytes_lone_surrogate:
  {pb("\"\\ud83dx\\udc00\"") == Some{Json.Str{"\u{FFFD}x\u{FFFD}"}} : Maybe<&2, Json.Val>}

law bytes_bad_hex_rejects:
  {pb("\"\\ud83d\\uzzzz\"") == None{} : Maybe<&2, Json.Val>}

law bytes_bad_escape_rejects:
  {pb("\"\\x\"") == None{} : Maybe<&2, Json.Val>}

law bytes_raw_control_rejects:
  {pb("\"a\nb\"") == None{} : Maybe<&2, Json.Val>}

law bytes_unterminated_rejects:
  {pb("\"abc") == None{} : Maybe<&2, Json.Val>}

law bytes_short_literal_rejects:
  {pb("tru") == None{} : Maybe<&2, Json.Val>}

law bytes_trailing_junk:
  {pb("null x") == None{} : Maybe<&2, Json.Val>}

# The end of input is not a NUL byte.
law bytes_nul_rejects:
  {pb("1\u{0}") == None{} : Maybe<&2, Json.Val>}

law bytes_empty_rejects:
  {pb(" ") == None{} : Maybe<&2, Json.Val>}

law bytes_trailing_comma_rejects:
  {pb("[1,]") == None{} : Maybe<&2, Json.Val>}

law bytes_wrong_close_rejects:
  {pb("[1}") == None{} : Maybe<&2, Json.Val>}

law bytes_empty_wrong_close_rejects:
  {pb("{]") == None{} : Maybe<&2, Json.Val>}

law bytes_missing_colon_rejects:
  {pb("{\"a\" 1}") == None{} : Maybe<&2, Json.Val>}

law bytes_unclosed_rejects:
  {pb("[{\"a\":[1]") == None{} : Maybe<&2, Json.Val>}

# Bytes: UTF-8 in strings and keys decodes to code points.
law bytes_utf8_two:
  {pb("\"h\u{c3}\u{a9}\"") == Some{Json.Str{"hé"}} : Maybe<&2, Json.Val>}

law bytes_utf8_three_four_key:
  {pb("{\"\u{f0}\u{9f}\u{98}\u{80}\":\"\u{e2}\u{82}\u{ac}\"}") == Some{obj1("😀", Json.Str{"€"})} : Maybe<&2, Json.Val>}

# §8.1: JSON text is UTF-8, so bad UTF-8 rejects.
law bytes_lone_continuation_rejects:
  {pb("\"\u{80}\"") == None{} : Maybe<&2, Json.Val>}

law bytes_overlong_rejects:
  {pb("\"\u{c0}\u{af}\"") == None{} : Maybe<&2, Json.Val>}

law bytes_surrogate_rejects:
  {pb("\"\u{ed}\u{a0}\u{80}\"") == None{} : Maybe<&2, Json.Val>}

law bytes_past_max_rejects:
  {pb("\"\u{f4}\u{90}\u{80}\u{80}\"") == None{} : Maybe<&2, Json.Val>}

law bytes_truncated_rejects:
  {pb("\"\u{c3}\"") == None{} : Maybe<&2, Json.Val>}

law bytes_truncated_at_end_rejects:
  {pb("\"\u{e2}\u{82}") == None{} : Maybe<&2, Json.Val>}

law bytes_non_ascii_outside_string_rejects:
  {pb("\u{c3}\u{a9}") == None{} : Maybe<&2, Json.Val>}

# encode.bytes is encode in UTF-8.
law encode_bytes_canonical:
  {eb(Json.Obj{Map.set(&2, Json.Val, Map.set(&2, Json.Val, Map.new(&2, Json.Val), "b", Json.Arr{[Json.Num{"1"}, Json.Num{"-2.5e3"}, Json.Flag{True{}}, Json.Null{}]}), "a", Json.Obj{Map.new(&2, Json.Val)})}) == "{\"a\":{},\"b\":[1,-2.5e3,true,null]}" : String}

law encode_bytes_escapes_utf8:
  {eb(obj1("k\u{e9}", Json.Str{"a\"\\\n\r\t\u{1f}\u{20ac}\u{1F600}"})) == "{\"k\u{c3}\u{a9}\":\"a\\\"\\\\\\n\\r\\t\\u001f\u{e2}\u{82}\u{ac}\u{f0}\u{9f}\u{98}\u{80}\"}" : String}

# The buffer holds the fewest words, as Bytes requires, below and past its first size.
law encode_bytes_small_buffer:
  {Json.encode.bytes(Json.Null{}) == Bytes.from_string("null") : Bytes.Bytes}

law encode_bytes_grown_buffer:
  {Json.encode.bytes(Json.Str{"0123456789012345678901234567890123456789012345678901234567890123456789"}) == Bytes.from_string("\"0123456789012345678901234567890123456789012345678901234567890123456789\"") : Bytes.Bytes}

law roundtrip_bytes:
  {Json.parse.bytes(Json.encode.bytes(Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})})) == Some{Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})}} : Maybe<&2, Json.Val>}
