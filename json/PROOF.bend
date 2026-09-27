import Base
import ./json.bend as Json
import ./LAWS.bend as Laws

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

def Laws.dup_key_last():
  {==}

def Laws.num_neg_frac_exp():
  {==}

def Laws.num_neg_zero():
  {==}

def Laws.num_big_exp():
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

def Laws.str_unicode_pair():
  {==}

def Laws.str_lone_surrogate():
  {==}

def Laws.str_raw_control_rejects():
  {==}

def Laws.str_bad_escape_rejects():
  {==}

def Laws.str_unterminated_rejects():
  {==}

def Laws.arr_trailing_comma_rejects():
  {==}

def Laws.arr_missing_comma_rejects():
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

def Laws.encode_canonical():
  {==}

def Laws.encode_escapes():
  {==}

def Laws.roundtrip():
  {==}

def Laws.bytes_nested():
  {==}

def Laws.bytes_ws():
  {==}

def Laws.bytes_deep():
  {==}

def Laws.bytes_empty_containers():
  {==}

def Laws.bytes_literals():
  {==}

def Laws.bytes_dup_key_last():
  {==}

def Laws.bytes_num_at_end():
  {==}

def Laws.bytes_num_in_arr():
  {==}

def Laws.bytes_num_leading_zero_rejects():
  {==}

def Laws.bytes_num_dot_end_rejects():
  {==}

def Laws.bytes_escapes():
  {==}

def Laws.bytes_unicode_pair():
  {==}

def Laws.bytes_lone_surrogate():
  {==}

def Laws.bytes_bad_hex_rejects():
  {==}

def Laws.bytes_bad_escape_rejects():
  {==}

def Laws.bytes_raw_control_rejects():
  {==}

def Laws.bytes_unterminated_rejects():
  {==}

def Laws.bytes_short_literal_rejects():
  {==}

def Laws.bytes_trailing_junk():
  {==}

def Laws.bytes_nul_rejects():
  {==}

def Laws.bytes_empty_rejects():
  {==}

def Laws.bytes_trailing_comma_rejects():
  {==}

def Laws.bytes_wrong_close_rejects():
  {==}

def Laws.bytes_empty_wrong_close_rejects():
  {==}

def Laws.bytes_missing_colon_rejects():
  {==}

def Laws.bytes_unclosed_rejects():
  {==}

def Laws.bytes_utf8_two():
  {==}

def Laws.bytes_utf8_three_four_key():
  {==}

def Laws.bytes_lone_continuation_rejects():
  {==}

def Laws.bytes_overlong_rejects():
  {==}

def Laws.bytes_surrogate_rejects():
  {==}

def Laws.bytes_past_max_rejects():
  {==}

def Laws.bytes_truncated_rejects():
  {==}

def Laws.bytes_truncated_at_end_rejects():
  {==}

def Laws.bytes_non_ascii_outside_string_rejects():
  {==}

def Laws.encode_bytes_canonical():
  {==}

def Laws.encode_bytes_escapes_utf8():
  {==}

def Laws.encode_bytes_small_buffer():
  {==}

def Laws.encode_bytes_grown_buffer():
  {==}

def Laws.roundtrip_bytes():
  {==}
