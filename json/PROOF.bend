import Base
import ./json.bend as Json
import ./LAWS.bend as Laws
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Additional concrete strict-mode evidence; human-owned LAWS stay unchanged.
def strict.high() -> {Json.parse.strict.bytes(Bytes.from_string("\"\\uD800\""), 64) == None{} : Maybe<&1, Json.Val>}:
  {==}

def strict.low() -> {Json.parse.strict.bytes(Bytes.from_string("\"\\uDC00\""), 64) == None{} : Maybe<&1, Json.Val>}:
  {==}

def strict.pair() -> {Json.parse.strict.bytes(Bytes.from_string("\"\\uD83D\\uDE00\""), 64) == Some{Json.Str{Json.utf8("😀")}} : Maybe<&1, Json.Val>}:
  {==}

def strict.depth() -> {Json.parse.strict.bytes(Bytes.from_string("[[]]"), 1) == None{} : Maybe<&1, Json.Val>}:
  {==}

def strict.number() -> {Json.parse.strict.bytes(Bytes.from_string("1e+02"), 0) == Some{Json.Num{Bytes.from_string("1e+02")}} : Maybe<&1, Json.Val>}:
  {==}

def Laws.parse_null():
  {==}

def Laws.parse_true():
  {==}

def Laws.parse_false():
  {==}

def Laws.parse_empty_arr():
  {==}

def Laws.parse_empty_obj():
  {==}

def Laws.at_index():
  {==}

def Laws.at_object_none():
  {==}

def Laws.get_key():
  {==}

def Laws.get_missing_none():
  {==}

def Laws.get_utf8_key():
  {==}

def Laws.get_array_none():
  {==}

def Laws.u32_twelve():
  {==}

def Laws.u32_fraction_none():
  {==}

def Laws.u32_overflow_none():
  {==}

def Laws.trailing_junk():
  {==}

def Laws.parse_nested():
  {==}

def Laws.parse_ws():
  {==}

def Laws.parse_deep():
  {==}

def Laws.empty_containers():
  {==}

def Laws.literals():
  {==}

def Laws.dup_key_kept():
  {==}

def Laws.dup_key_last():
  {==}

def Laws.num_neg_frac_exp():
  {==}

def Laws.num_neg_zero():
  {==}

def Laws.num_big_exp():
  {==}

def Laws.num_in_arr():
  {==}

def Laws.num_leading_zero_rejects():
  {==}

def Laws.num_bare_minus_rejects():
  {==}

def Laws.num_dot_end_rejects():
  {==}

def Laws.num_dot_start_rejects():
  {==}

def Laws.num_exp_end_rejects():
  {==}

def Laws.num_plus_rejects():
  {==}

def Laws.str_escapes():
  {==}

def Laws.str_escape_after_word():
  {==}

def Laws.str_unicode_pair():
  {==}

def Laws.str_lone_surrogate():
  {==}

def Laws.str_lone_surrogates():
  {==}

def Laws.str_bad_hex_rejects():
  {==}

def Laws.str_raw_control_rejects():
  {==}

def Laws.str_bad_escape_rejects():
  {==}

def Laws.str_unterminated_rejects():
  {==}

def Laws.short_literal_rejects():
  {==}

def Laws.nul_rejects():
  {==}

def Laws.arr_trailing_comma_rejects():
  {==}

def Laws.arr_missing_comma_rejects():
  {==}

def Laws.wrong_close_rejects():
  {==}

def Laws.empty_wrong_close_rejects():
  {==}

def Laws.obj_missing_colon_rejects():
  {==}

def Laws.obj_trailing_comma_rejects():
  {==}

def Laws.obj_number_key_rejects():
  {==}

def Laws.unclosed_rejects():
  {==}

def Laws.empty_rejects():
  {==}

def Laws.utf8_two():
  {==}

def Laws.utf8_three_four_key():
  {==}

def Laws.utf8_lone_continuation_rejects():
  {==}

def Laws.utf8_overlong_rejects():
  {==}

def Laws.utf8_surrogate_rejects():
  {==}

def Laws.utf8_past_max_rejects():
  {==}

def Laws.utf8_truncated_rejects():
  {==}

def Laws.utf8_truncated_at_end_rejects():
  {==}

def Laws.non_ascii_outside_string_rejects():
  {==}

def Laws.encode_compact():
  {==}

def Laws.encode_escapes():
  {==}

def Laws.encode_small_buffer():
  {==}

def Laws.encode_grown_buffer():
  {==}

def Laws.roundtrip():
  {==}
