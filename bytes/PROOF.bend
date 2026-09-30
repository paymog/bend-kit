import Base
import ./bytes.bend as Bytes
import ./LAWS.bend as Laws

def Laws.roundtrip_empty():
  {==}

def Laws.roundtrip_word():
  {==}

def Laws.roundtrip_words():
  {==}

def Laws.roundtrip_octets():
  {==}

def Laws.from_masks():
  {==}

def Laws.new_zeros():
  {==}

def Laws.length_of():
  {==}

def Laws.get_first():
  {==}

def Laws.get_second_word():
  {==}

def Laws.get_past_len():
  {==}

def Laws.set_middle():
  {==}

def Laws.set_second_word():
  {==}

def Laws.set_masks():
  {==}

def Laws.set_past_len():
  {==}

def Laws.slice_middle():
  {==}

def Laws.slice_keeps_source():
  {==}

def Laws.slice_clamps_count():
  {==}

def Laws.slice_clamps_start():
  {==}

def Laws.append_two():
  {==}

def Laws.append_empty():
  {==}

def Laws.find_header_end():
  {==}

def Laws.find_across_words():
  {==}

def Laws.find_first_of_two():
  {==}

def Laws.find_at_end():
  {==}

def Laws.find_missing():
  {==}

def Laws.find_needle_too_long():
  {==}

def Laws.find_empty_needle():
  {==}

def Laws.eq_same():
  {==}

def Laws.eq_last_byte():
  {==}

def Laws.eq_length():
  {==}

def Laws.eq_empty():
  {==}

def Laws.eq_after_set():
  {==}

def Laws.eq_after_append():
  {==}

def Laws.roundtrip_one():
  {==}

def Laws.roundtrip_three():
  {==}

def Laws.roundtrip_seven():
  {==}

def Laws.slice_offset_1():
  {==}

def Laws.slice_offset_2():
  {==}

def Laws.slice_offset_3():
  {==}

def Laws.slice_aligned():
  {==}

def Laws.slice_to_end():
  {==}

def Laws.slice_octets():
  {==}

def Laws.append_aligned():
  {==}

def Laws.append_unaligned():
  {==}

def Laws.eq_after_slice():
  {==}

def Laws.eq_after_aligned_append():
  {==}

def Laws.concat_pieces():
  {==}

def Laws.concat_none():
  {==}

def Laws.append_in_room():
  {==}

def Laws.append_grows():
  {==}

def Laws.eq_after_appends():
  {==}

def Laws.u16be_at():
  {==}

def Laws.u16le_at():
  {==}

def Laws.u32be_across_words():
  {==}

def Laws.u32le_across_words():
  {==}

def Laws.u32be_top():
  {==}

def Laws.u32_past_len():
  {==}

def Laws.u16_past_len():
  {==}

def Laws.set_u16be_at():
  {==}

def Laws.set_u16le_masks():
  {==}

def Laws.set_u32be_across_words():
  {==}

def Laws.set_u32le_across_words():
  {==}

def Laws.set_u16_past_len():
  {==}

def Laws.u16be_roundtrip():
  {==}

def Laws.u16le_roundtrip():
  {==}

def Laws.u32be_roundtrip():
  {==}

def Laws.u32le_roundtrip():
  {==}

def Laws.u64be_across_words():
  {==}

def Laws.u64le_across_words():
  {==}

def Laws.u64be_top():
  {==}

def Laws.u64_past_len():
  {==}

def Laws.u64_half_past_len():
  {==}

def Laws.set_u64be_across_words():
  {==}

def Laws.set_u64le_across_words():
  {==}

def Laws.set_u64_half_past_len():
  {==}

def Laws.u64be_roundtrip():
  {==}

def Laws.u64le_roundtrip():
  {==}

def Laws.find_from_later():
  {==}

def Laws.find_from_at_start():
  {==}

def Laws.find_from_too_late():
  {==}

def Laws.find_from_empty_at_len():
  {==}

def Laws.find_from_past_len():
  {==}

def Laws.rfind_last():
  {==}

def Laws.rfind_at_end():
  {==}

def Laws.rfind_at_zero():
  {==}

def Laws.rfind_missing():
  {==}

def Laws.rfind_too_long():
  {==}

def Laws.rfind_empty():
  {==}

def Laws.starts_with_method():
  {==}

def Laws.starts_with_other():
  {==}

def Laws.starts_with_too_long():
  {==}

def Laws.starts_with_empty():
  {==}

def Laws.ends_with_crlf():
  {==}

def Laws.ends_with_other():
  {==}

def Laws.ends_with_too_long():
  {==}

def Laws.split_fields():
  {==}

def Laws.split_ends():
  {==}

def Laws.split_no_overlap():
  {==}

def Laws.split_lines():
  {==}

def Laws.split_empty_sep():
  {==}

def Laws.split_empty():
  {==}

def Laws.split_sep_too_long():
  {==}

def Laws.cmp_first_byte():
  {==}

def Laws.cmp_last_byte():
  {==}

def Laws.cmp_second_word():
  {==}

def Laws.cmp_unsigned():
  {==}

def Laws.cmp_prefix():
  {==}

def Laws.cmp_zero_tail():
  {==}

def Laws.cmp_equal():
  {==}

def Laws.to_hex_octets():
  {==}

def Laws.to_hex_empty():
  {==}

def Laws.from_hex_either_case():
  {==}

def Laws.from_hex_odd():
  {==}

def Laws.from_hex_bad_char():
  {==}

def Laws.from_hex_empty():
  {==}

def Laws.base64_empty():
  {==}

def Laws.base64_f():
  {==}

def Laws.base64_fo():
  {==}

def Laws.base64_foo():
  {==}

def Laws.base64_foob():
  {==}

def Laws.base64_fooba():
  {==}

def Laws.base64_foobar():
  {==}

def Laws.base64_high_octets():
  {==}

def Laws.from_base64_f():
  {==}

def Laws.from_base64_fo():
  {==}

def Laws.from_base64_foobar():
  {==}

def Laws.from_base64_fooba():
  {==}

def Laws.from_base64_high_octets():
  {==}

def Laws.from_base64_empty():
  {==}

def Laws.from_base64_length():
  {==}

def Laws.from_base64_inner_pad():
  {==}

def Laws.from_base64_three_pads():
  {==}

def Laws.from_base64_bad_char():
  {==}

def Laws.from_base64_foob():
  {==}

def Laws.from_base64_pad_bits():
  {==}

def Laws.cursor_read_crosses_word():
  {==}

def Laws.cursor_read_incomplete():
  {==}

def Laws.cursor_write_incomplete():
  {==}

def Laws.cursor_write_crosses_word():
  {==}

def Laws.cursor_skip_overflow():
  {==}

def Laws.cursor_region_bounds():
  {==}

def Laws.cursor_region_enters():
  {==}

def Laws.cursor_region_incomplete():
  {==}

def Laws.cursor_region_empty():
  {==}

def Laws.cursor_leave_skips_unread():
  {==}

def Laws.cursor_region_seek_before_start():
  {==}

def Laws.cursor_region_write_incomplete():
  {==}

def Laws.cursor_skip_advances():
  {==}

def Laws.cursor_skip_to_end():
  {==}

def Laws.cursor_skip_zero():
  {==}

def Laws.cursor_seek_past_end():
  {==}

def Laws.cursor_seek_to_end():
  {==}

def Laws.cursor_read_empty():
  {==}

def Laws.cursor_u64be():
  {==}

def Laws.cursor_u64le():
  {==}

def Laws.cursor_u64_incomplete():
  {==}
